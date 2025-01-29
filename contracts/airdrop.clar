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

;; Define data variables
(define-data-var is-reward-active bool true)
(define-data-var total-tokens-released uint u0)
(define-data-var reward-amount-per-participant uint u100)
(define-data-var reward-start-block uint block-height)
(define-data-var collection-period-length uint u10000) ;; Number of blocks after which unclaimed tokens can be collected

;; Define data maps
(define-map eligible-reward-participants principal bool)
(define-map claimed-reward-amounts principal uint)

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

(define-read-only (get-event (event-id uint))
  (map-get? contract-events event-id))

;; Contract initialization

(begin
  (ft-mint? reward-token u1000000000 CONTRACT-OWNER))