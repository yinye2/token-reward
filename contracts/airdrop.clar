;; Token Reward Distribution Contract

;; Define constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERROR-NOT-CONTRACT-OWNER (err u100))
(define-constant ERROR-REWARD-ALREADY-CLAIMED (err u101))
(define-constant ERROR-PARTICIPANT-NOT-ELIGIBLE (err u102))
(define-constant ERROR-INSUFFICIENT-TOKEN-BALANCE (err u103))
(define-constant ERROR-REWARD-NOT-ACTIVE (err u104))
(define-constant ERROR-INVALID-AMOUNT (err u105))
(define-constant ERROR-COLLECTION-PERIOD-NOT-ENDED (err u106))
(define-constant ERROR-INVALID-PARTICIPANT (err u107))
(define-constant ERROR-INVALID-TIMEFRAME (err u108))
(define-constant ERROR-ALREADY-STAKED (err u109))
(define-constant ERROR-NOT-STAKED (err u110))
(define-constant ERROR-STAKE-LOCKED (err u111))
(define-constant STAKE-LOCK-PERIOD u144) ;; About 24 hours in blocks
(define-constant STAKE-REWARD-RATE u5) ;; 5% reward rate

;; Define data variables
(define-data-var is-reward-active bool true)
(define-data-var total-tokens-released uint u0)
(define-data-var reward-amount-per-participant uint u100)
(define-data-var reward-start-block uint block-height)
(define-data-var collection-period-length uint u10000)
(define-data-var total-staked-tokens uint u0)

;; Define data maps
(define-map eligible-reward-participants principal bool)
(define-map claimed-reward-amounts principal uint)
(define-map staking-positions principal {
    amount: uint,
    start-block: uint,
    last-reward-block: uint
})

;; Define fungible token
(define-fungible-token reward-token)

;; Define events
(define-data-var next-event-id uint u0)
(define-map contract-events uint {event-type: (string-ascii 20), data: (string-ascii 256)})

;; Event logging function
(define-private (log-event (event-type (string-ascii 20)) (data (string-ascii 256)))
  (let ((event-id (var-get next-event-id)))
    (map-set contract-events event-id {event-type: event-type, data: data})
    (var-set next-event-id (+ event-id u1))
    event-id))

;; Staking functions

(define-private (calculate-staking-reward (staked-amount uint) (blocks-staked uint))
  (let (
    (reward-rate STAKE-REWARD-RATE)
    (blocks-per-year u52560) ;; Approximately 52560 blocks per year
    (reward (* (* staked-amount reward-rate) (/ blocks-staked blocks-per-year)))
  )
    (/ reward u100))) ;; Divide by 100 since rate is in percentage

(define-public (stake-tokens (amount uint))
  (let (
    (sender tx-sender)
    (current-stake (map-get? staking-positions sender))
  )
    (asserts! (is-none current-stake) ERROR-ALREADY-STAKED)
    (asserts! (>= (ft-get-balance reward-token sender) amount) ERROR-INSUFFICIENT-TOKEN-BALANCE)
    (try! (ft-transfer? reward-token amount sender (as-contract tx-sender)))
    (map-set staking-positions sender {
      amount: amount,
      start-block: block-height,
      last-reward-block: block-height
    })
    (var-set total-staked-tokens (+ (var-get total-staked-tokens) amount))
    (log-event "stake-tokens" "tokens staked")
    (ok amount)))

(define-public (unstake-tokens)
  (let (
    (sender tx-sender)
    (stake (unwrap! (map-get? staking-positions sender) ERROR-NOT-STAKED))
    (current-block block-height)
    (blocks-staked (- current-block (get start-block stake)))
  )
    (asserts! (>= blocks-staked STAKE-LOCK-PERIOD) ERROR-STAKE-LOCKED)
    (let (
      (staked-amount (get amount stake))
      (reward-amount (calculate-staking-reward staked-amount blocks-staked))
    )
      (try! (as-contract (ft-transfer? reward-token staked-amount (as-contract tx-sender) sender)))
      (try! (as-contract (ft-transfer? reward-token reward-amount (as-contract tx-sender) sender)))
      (map-delete staking-positions sender)
      (var-set total-staked-tokens (- (var-get total-staked-tokens) staked-amount))
      (log-event "unstake-tokens" "tokens unstaked")
      (ok {staked-amount: staked-amount, reward-amount: reward-amount}))))

(define-read-only (get-staking-position (staker principal))
  (map-get? staking-positions staker))

(define-read-only (get-current-reward (staker principal))
  (match (map-get? staking-positions staker)
    stake (let (
      (blocks-staked (- block-height (get start-block stake)))
    )
      (ok (calculate-staking-reward (get amount stake) blocks-staked)))
    (err u0)))

;; Admin functions

(define-public (add-eligible-participant (participant-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-NOT-CONTRACT-OWNER)
    (asserts! (is-none (map-get? eligible-reward-participants participant-address)) ERROR-INVALID-PARTICIPANT)
    (log-event "participant-add" "new participant")
    (ok (map-set eligible-reward-participants participant-address true))))

(define-public (remove-eligible-participant (participant-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-NOT-CONTRACT-OWNER)
    (asserts! (is-some (map-get? eligible-reward-participants participant-address)) ERROR-PARTICIPANT-NOT-ELIGIBLE)
    (log-event "participant-remove" "removed participant")
    (ok (map-delete eligible-reward-participants participant-address))))

(define-public (bulk-add-eligible-participants (participant-addresses (list 200 principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-NOT-CONTRACT-OWNER)
    (log-event "bulk-add" "participants added")
    (ok (map add-eligible-participant participant-addresses))))

(define-public (update-reward-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-NOT-CONTRACT-OWNER)
    (asserts! (> new-amount u0) ERROR-INVALID-AMOUNT)
    (var-set reward-amount-per-participant new-amount)
    (log-event "amount-updated" "amount changed")
    (ok new-amount)))

(define-public (update-collection-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-NOT-CONTRACT-OWNER)
    (asserts! (> new-period u0) ERROR-INVALID-TIMEFRAME)
    (var-set collection-period-length new-period)
    (log-event "period-updated" "collection period changed")
    (ok new-period)))

;; Reward distribution function

(define-public (claim-reward-tokens)
  (let (
    (participant-address tx-sender)
    (claim-amount (var-get reward-amount-per-participant))
  )
    (asserts! (var-get is-reward-active) ERROR-REWARD-NOT-ACTIVE)
    (asserts! (is-some (map-get? eligible-reward-participants participant-address)) ERROR-PARTICIPANT-NOT-ELIGIBLE)
    (asserts! (is-none (map-get? claimed-reward-amounts participant-address)) ERROR-REWARD-ALREADY-CLAIMED)
    (asserts! (<= claim-amount (ft-get-balance reward-token CONTRACT-OWNER)) ERROR-INSUFFICIENT-TOKEN-BALANCE)
    (try! (ft-transfer? reward-token claim-amount CONTRACT-OWNER participant-address))
    (map-set claimed-reward-amounts participant-address claim-amount)
    (var-set total-tokens-released (+ (var-get total-tokens-released) claim-amount))
    (log-event "tokens-claimed" "tokens claimed")
    (ok claim-amount)))

;; Token collection function

(define-public (collect-unclaimed-tokens)
  (let (
    (current-block block-height)
    (collection-allowed-after (+ (var-get reward-start-block) (var-get collection-period-length)))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERROR-NOT-CONTRACT-OWNER)
    (asserts! (>= current-block collection-allowed-after) ERROR-COLLECTION-PERIOD-NOT-ENDED)
    (let (
      (total-minted (ft-get-supply reward-token))
      (total-claimed (var-get total-tokens-released))
      (unclaimed-amount (- total-minted total-claimed))
    )
      (try! (ft-burn? reward-token unclaimed-amount CONTRACT-OWNER))
      (log-event "tokens-collected" "unclaimed tokens burned")
      (ok unclaimed-amount))))

;; Read-only functions

(define-read-only (get-reward-active-status)
  (var-get is-reward-active))

(define-read-only (is-participant-eligible (participant-address principal))
  (default-to false (map-get? eligible-reward-participants participant-address)))

(define-read-only (has-participant-claimed-reward (participant-address principal))
  (is-some (map-get? claimed-reward-amounts participant-address)))

(define-read-only (get-participant-claimed-amount (participant-address principal))
  (default-to u0 (map-get? claimed-reward-amounts participant-address)))

(define-read-only (get-total-tokens-released)
  (var-get total-tokens-released))

(define-read-only (get-reward-amount-per-participant)
  (var-get reward-amount-per-participant))

(define-read-only (get-collection-period)
  (var-get collection-period-length))

(define-read-only (get-reward-start-block)
  (var-get reward-start-block))

(define-read-only (get-total-staked-tokens)
  (var-get total-staked-tokens))

(define-read-only (get-event (event-id uint))
  (map-get? contract-events event-id))

;; Contract initialization

(begin
  (ft-mint? reward-token u1000000000 CONTRACT-OWNER))