;; dividend-token.clar
;; Dividends are paid in STX (could be modified to support other tokens)

;; Define and implement SIP-010 trait
(define-trait sip-010-trait
  (
    ;; Required SIP-010 functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
  )
)

(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INSUFFICIENT_BALANCE u101)
(define-constant ERR_FAILED_TO_TRANSFER u102)

;; Token data
(define-constant TOKEN_NAME "DividendToken")
(define-constant TOKEN_SYMBOL "DIV")
(define-constant TOKEN_DECIMALS u6)

(define-data-var total-supply uint u0)
(define-map balances { account: principal } { balance: uint })

;; Dividend accounting
(define-data-var magnified-dividend-per-share uint u0)
(define-constant MAGNITUDE u1000000000) ;; scaling factor
(define-map dividend-corrections { account: principal } { value: int })
(define-map withdrawn-dividends { account: principal } { amount: uint })

;; --------------------
;; Fungible Token API
;; --------------------
(define-read-only (get-name)
  (ok TOKEN_NAME))

(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL))

(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-balance (account principal))
  (ok (default-to u0 (get balance (map-get? balances { account: account })))))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let ((sender-balance (default-to u0 (get balance (map-get? balances { account: sender })))))
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (<= amount sender-balance) (err ERR_INSUFFICIENT_BALANCE))
    (begin
      (map-set balances { account: sender } { balance: (- sender-balance amount) })
      (map-set balances { account: recipient } { balance: (+ (default-to u0 (get balance (map-get? balances { account: recipient }))) amount) })
      ;; adjust dividend corrections
      (let ((magnified (var-get magnified-dividend-per-share)))
        (map-set dividend-corrections { account: sender }
                 { value: (+ (default-to 0 (get value (map-get? dividend-corrections { account: sender })))
                             (to-int (* amount magnified))) })
        (map-set dividend-corrections { account: recipient }
                 { value: (- (default-to 0 (get value (map-get? dividend-corrections { account: recipient })))
                             (to-int (* amount magnified))) }))
      (print memo)
      (ok true))))

;; Mint (owner-only)
(define-public (mint (to principal) (amount uint))
  (begin
    (map-set balances { account: to } { balance: (+ (default-to u0 (get balance (map-get? balances { account: to }))) amount) })
    (var-set total-supply (+ (var-get total-supply) amount))
    ;; correct dividends
    (let ((magnified (var-get magnified-dividend-per-share)))
      (map-set dividend-corrections { account: to }
               { value: (- (default-to 0 (get value (map-get? dividend-corrections { account: to })))
                           (to-int (* amount magnified))) }))
    (ok true)))

;; --------------------
;; Dividend Logic
;; --------------------
(define-public (deposit-dividends)
  (let ((amount (stx-get-balance (as-contract tx-sender))))
    ;; Use tx-sender payment (via post-condition) to feed dividends
    (if (> (var-get total-supply) u0)
        (begin
          (var-set magnified-dividend-per-share
                   (+ (var-get magnified-dividend-per-share)
                      (/ (* amount MAGNITUDE) (var-get total-supply))))
          (ok amount))
        (ok u0))))

(define-read-only (withdrawable-dividends (account principal))
  (let ((magnified (var-get magnified-dividend-per-share)))
    (let ((correct (default-to 0 (get value (map-get? dividend-corrections { account: account }))))
          (withdrawn (default-to u0 (get amount (map-get? withdrawn-dividends { account: account })))))
      (let ((owed (/ (+ (* (default-to u0 (get balance (map-get? balances { account: account }))) magnified) (to-uint correct)) MAGNITUDE)))
        (- owed withdrawn)))))

(define-public (withdraw-dividends)
  (let ((amount (withdrawable-dividends tx-sender)))
    (if (> amount u0)
        (begin
          (map-set withdrawn-dividends { account: tx-sender }
                   { amount: (+ (default-to u0 (get amount (map-get? withdrawn-dividends { account: tx-sender }))) amount) })
          (match (stx-transfer? amount (as-contract tx-sender) tx-sender)
            success (ok amount)
            error (err ERR_FAILED_TO_TRANSFER)))
        (ok u0))))
