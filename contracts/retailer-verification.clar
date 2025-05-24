;; Retailer Verification Contract
;; Validates and manages merchant registrations

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Retailer verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_SUSPENDED u3)

;; Data structures
(define-map retailers
  { retailer-id: principal }
  {
    business-name: (string-ascii 100),
    registration-date: uint,
    verification-status: uint,
    category: (string-ascii 50),
    verified-by: (optional principal)
  }
)

(define-map retailer-metrics
  { retailer-id: principal }
  {
    total-customers: uint,
    total-touchpoints: uint,
    reputation-score: uint
  }
)

;; Register a new retailer
(define-public (register-retailer (business-name (string-ascii 100)) (category (string-ascii 50)))
  (let ((retailer-id tx-sender))
    (asserts! (is-none (map-get? retailers { retailer-id: retailer-id })) ERR_ALREADY_VERIFIED)
    (map-set retailers
      { retailer-id: retailer-id }
      {
        business-name: business-name,
        registration-date: block-height,
        verification-status: STATUS_PENDING,
        category: category,
        verified-by: none
      }
    )
    (map-set retailer-metrics
      { retailer-id: retailer-id }
      {
        total-customers: u0,
        total-touchpoints: u0,
        reputation-score: u50
      }
    )
    (ok retailer-id)
  )
)

;; Verify a retailer (admin only)
(define-public (verify-retailer (retailer-id principal) (status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= status STATUS_SUSPENDED) ERR_INVALID_STATUS)
    (match (map-get? retailers { retailer-id: retailer-id })
      retailer-data
      (begin
        (map-set retailers
          { retailer-id: retailer-id }
          (merge retailer-data {
            verification-status: status,
            verified-by: (some tx-sender)
          })
        )
        (ok true)
      )
      ERR_NOT_FOUND
    )
  )
)

;; Update retailer metrics
(define-public (update-metrics (retailer-id principal) (customers uint) (touchpoints uint) (reputation uint))
  (begin
    (asserts! (is-verified retailer-id) ERR_UNAUTHORIZED)
    (map-set retailer-metrics
      { retailer-id: retailer-id }
      {
        total-customers: customers,
        total-touchpoints: touchpoints,
        reputation-score: reputation
      }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-retailer (retailer-id principal))
  (map-get? retailers { retailer-id: retailer-id })
)

(define-read-only (get-retailer-metrics (retailer-id principal))
  (map-get? retailer-metrics { retailer-id: retailer-id })
)

(define-read-only (is-verified (retailer-id principal))
  (match (map-get? retailers { retailer-id: retailer-id })
    retailer-data (is-eq (get verification-status retailer-data) STATUS_VERIFIED)
    false
  )
)
