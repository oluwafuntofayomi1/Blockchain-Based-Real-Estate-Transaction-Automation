;; Closing Coordination Contract
;; Coordinates transaction closings

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_INVALID_STATUS (err u402))
(define-constant ERR_PREREQUISITES_NOT_MET (err u403))

;; Closing statuses
(define-constant STATUS_SCHEDULED "scheduled")
(define-constant STATUS_IN_PROGRESS "in-progress")
(define-constant STATUS_COMPLETED "completed")
(define-constant STATUS_CANCELLED "cancelled")

;; Data structures
(define-map closings
  { contract-id: uint }
  {
    coordinator: principal,
    closing-date: uint,
    closing-location: (string-ascii 200),
    status: (string-ascii 20),
    title-company: principal,
    buyer-funds-verified: bool,
    seller-docs-ready: bool,
    title-clear: bool,
    final-walkthrough-complete: bool
  }
)

(define-map closing-participants
  { contract-id: uint, participant: principal }
  {
    role: (string-ascii 50),
    attendance-confirmed: bool,
    documents-signed: bool
  }
)

;; Public functions
(define-public (schedule-closing
  (contract-id uint)
  (coordinator principal)
  (closing-date uint)
  (closing-location (string-ascii 200))
  (title-company principal))
  (begin
    (map-set closings
      { contract-id: contract-id }
      {
        coordinator: coordinator,
        closing-date: closing-date,
        closing-location: closing-location,
        status: STATUS_SCHEDULED,
        title-company: title-company,
        buyer-funds-verified: false,
        seller-docs-ready: false,
        title-clear: false,
        final-walkthrough-complete: false
      }
    )
    (ok true)
  )
)

(define-public (add-closing-participant
  (contract-id uint)
  (participant principal)
  (role (string-ascii 50)))
  (match (map-get? closings { contract-id: contract-id })
    closing-data
    (begin
      (asserts! (is-eq tx-sender (get coordinator closing-data)) ERR_UNAUTHORIZED)
      (map-set closing-participants
        { contract-id: contract-id, participant: participant }
        {
          role: role,
          attendance-confirmed: false,
          documents-signed: false
        }
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (update-closing-prerequisite
  (contract-id uint)
  (prerequisite (string-ascii 50))
  (completed bool))
  (match (map-get? closings { contract-id: contract-id })
    closing-data
    (begin
      (asserts! (or (is-eq tx-sender (get coordinator closing-data))
                    (is-eq tx-sender (get title-company closing-data))) ERR_UNAUTHORIZED)
      (let ((updated-closing
        (if (is-eq prerequisite "buyer-funds")
          (merge closing-data { buyer-funds-verified: completed })
          (if (is-eq prerequisite "seller-docs")
            (merge closing-data { seller-docs-ready: completed })
            (if (is-eq prerequisite "title-clear")
              (merge closing-data { title-clear: completed })
              (if (is-eq prerequisite "final-walkthrough")
                (merge closing-data { final-walkthrough-complete: completed })
                closing-data))))))
        (map-set closings { contract-id: contract-id } updated-closing)
        (ok true)
      )
    )
    ERR_NOT_FOUND
  )
)

(define-public (confirm-attendance (contract-id uint))
  (match (map-get? closing-participants { contract-id: contract-id, participant: tx-sender })
    participant-data
    (begin
      (map-set closing-participants
        { contract-id: contract-id, participant: tx-sender }
        (merge participant-data { attendance-confirmed: true })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (complete-closing (contract-id uint))
  (match (map-get? closings { contract-id: contract-id })
    closing-data
    (begin
      (asserts! (is-eq tx-sender (get coordinator closing-data)) ERR_UNAUTHORIZED)
      (asserts! (and (get buyer-funds-verified closing-data)
                     (get seller-docs-ready closing-data)
                     (get title-clear closing-data)
                     (get final-walkthrough-complete closing-data)) ERR_PREREQUISITES_NOT_MET)
      (map-set closings
        { contract-id: contract-id }
        (merge closing-data { status: STATUS_COMPLETED })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-closing (contract-id uint))
  (map-get? closings { contract-id: contract-id })
)

(define-read-only (get-closing-participant (contract-id uint) (participant principal))
  (map-get? closing-participants { contract-id: contract-id, participant: participant })
)

(define-read-only (is-ready-to-close (contract-id uint))
  (match (map-get? closings { contract-id: contract-id })
    closing-data
    (and (get buyer-funds-verified closing-data)
         (get seller-docs-ready closing-data)
         (get title-clear closing-data)
         (get final-walkthrough-complete closing-data))
    false
  )
)
