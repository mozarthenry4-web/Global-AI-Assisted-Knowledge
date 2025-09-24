;; Global AI-Assisted Knowledge (GAIAK) Platform
;; A decentralized knowledge ecosystem with AI-powered curation and community governance
;; Version: 1.0.0
;; Compatible with: Clarinet 3.x

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_KNOWLEDGE_NOT_FOUND (err u404))
(define-constant ERR_VALIDATION_NOT_FOUND (err u405))
(define-constant ERR_INSUFFICIENT_TOKENS (err u402))
(define-constant ERR_INVALID_PARAMETERS (err u400))
(define-constant ERR_ALREADY_VOTED (err u409))
(define-constant ERR_VALIDATION_CLOSED (err u408))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u407))
(define-constant ERR_AI_ANALYSIS_PENDING (err u406))

;; Data Variables
(define-data-var knowledge-counter uint u0)
(define-data-var validation-counter uint u0)
(define-data-var total-knowledge-tokens uint u1000000) ;; Total supply of knowledge tokens
(define-data-var platform-fee-percentage uint u3) ;; 3% platform fee
(define-data-var min-reputation-threshold uint u10) ;; Minimum reputation to submit knowledge
(define-data-var ai-analysis-fee uint u100) ;; Cost for AI analysis in microSTX
(define-data-var validation-period uint u1008) ;; Validation period in blocks (~7 days)

;; Knowledge Categories
(define-constant CATEGORY_SCIENCE u1)
(define-constant CATEGORY_TECHNOLOGY u2)
(define-constant CATEGORY_MEDICINE u3)
(define-constant CATEGORY_EDUCATION u4)
(define-constant CATEGORY_RESEARCH u5)
(define-constant CATEGORY_AI_ML u6)

;; Knowledge Quality Levels (AI-determined)
(define-constant QUALITY_EXCELLENT u5)
(define-constant QUALITY_GOOD u4)
(define-constant QUALITY_AVERAGE u3)
(define-constant QUALITY_POOR u2)
(define-constant QUALITY_UNVERIFIED u1)

;; Status Constants
(define-constant STATUS_PENDING u1)
(define-constant STATUS_AI_ANALYZING u2)
(define-constant STATUS_COMMUNITY_VALIDATION u3)
(define-constant STATUS_VALIDATED u4)
(define-constant STATUS_REJECTED u5)

;; Data Maps
(define-map knowledge-entries 
    { knowledge-id: uint }
    {
        contributor: principal,
        title: (string-ascii 128),
        summary: (string-ascii 512),
        content-hash: (buff 32),
        category: uint,
        ai-quality-score: uint,
        ai-confidence: uint,
        community-votes-for: uint,
        community-votes-against: uint,
        total-validators: uint,
        status: uint,
        token-rewards: uint,
        access-count: uint,
        created-at: uint,
        validated-at: (optional uint)
    }
)

(define-map knowledge-validations 
    { validation-id: uint }
    {
        knowledge-id: uint,
        validator: principal,
        quality-rating: uint,
        accuracy-rating: uint,
        usefulness-rating: uint,
        feedback: (string-ascii 256),
        validation-stake: uint,
        reward-claimed: bool,
        validated-at: uint
    }
)

(define-map contributor-profiles
    { contributor: principal }
    {
        name: (string-ascii 64),
        expertise-areas: (string-ascii 128),
        reputation-score: uint,
        knowledge-contributed: uint,
        validations-performed: uint,
        tokens-earned: uint,
        ai-collaboration-score: uint
    }
)

(define-map knowledge-tokens
    { holder: principal }
    { balance: uint }
)

(define-map ai-analysis-results
    { knowledge-id: uint }
    {
        originality-score: uint,
        factual-accuracy: uint,
        completeness-score: uint,
        clarity-score: uint,
        relevance-score: uint,
        bias-detection: uint,
        confidence-level: uint,
        analysis-timestamp: uint
    }
)

(define-map knowledge-access-log
    { knowledge-id: uint, accessor: principal }
    {
        access-count: uint,
        last-accessed: uint,
        tokens-paid: uint
    }
)

(define-map expert-endorsements
    { knowledge-id: uint, expert: principal }
    {
        endorsement-weight: uint,
        expertise-relevance: uint,
        endorsed-at: uint
    }
)

;; Public Functions

;; Create contributor profile
(define-public (create-contributor-profile 
    (name (string-ascii 64))
    (expertise-areas (string-ascii 128)))
    (begin
        (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len expertise-areas) u0) ERR_INVALID_PARAMETERS)
        
        (map-set contributor-profiles { contributor: tx-sender }
            {
                name: name,
                expertise-areas: expertise-areas,
                reputation-score: u0,
                knowledge-contributed: u0,
                validations-performed: u0,
                tokens-earned: u0,
                ai-collaboration-score: u50
            }
        )
        
        ;; Grant initial knowledge tokens
        (map-set knowledge-tokens { holder: tx-sender } { balance: u1000 })
        (ok true)
    )
)

;; Submit knowledge entry for AI analysis and community validation
(define-public (submit-knowledge
    (title (string-ascii 128))
    (summary (string-ascii 512))
    (content-hash (buff 32))
    (category uint))
    (let 
        (
            (new-knowledge-id (+ (var-get knowledge-counter) u1))
            (contributor-profile (map-get? contributor-profiles { contributor: tx-sender }))
        )
        (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len summary) u0) ERR_INVALID_PARAMETERS)
        (asserts! (and (>= category u1) (<= category u6)) ERR_INVALID_PARAMETERS)
        (asserts! (is-some contributor-profile) ERR_UNAUTHORIZED)
        (asserts! (>= (get reputation-score (unwrap-panic contributor-profile)) 
                     (var-get min-reputation-threshold)) ERR_INSUFFICIENT_REPUTATION)
        (asserts! (>= (stx-get-balance tx-sender) (var-get ai-analysis-fee)) ERR_INSUFFICIENT_TOKENS)
        
        ;; Pay AI analysis fee
        (try! (stx-transfer? (var-get ai-analysis-fee) tx-sender (as-contract tx-sender)))
        
        (map-set knowledge-entries { knowledge-id: new-knowledge-id }
            {
                contributor: tx-sender,
                title: title,
                summary: summary,
                content-hash: content-hash,
                category: category,
                ai-quality-score: u0,
                ai-confidence: u0,
                community-votes-for: u0,
                community-votes-against: u0,
                total-validators: u0,
                status: STATUS_AI_ANALYZING,
                token-rewards: u0,
                access-count: u0,
                created-at: burn-block-height,
                validated-at: none
            }
        )
        
        ;; Update contributor stats
        (map-set contributor-profiles { contributor: tx-sender }
            (merge (unwrap-panic contributor-profile) {
                knowledge-contributed: (+ (get knowledge-contributed (unwrap-panic contributor-profile)) u1)
            })
        )
        
        (var-set knowledge-counter new-knowledge-id)
        (ok new-knowledge-id)
    )
)

;; AI system submits analysis results (called by authorized AI oracle)
(define-public (submit-ai-analysis
    (knowledge-id uint)
    (originality-score uint)
    (factual-accuracy uint)
    (completeness-score uint)
    (clarity-score uint)
    (relevance-score uint)
    (bias-detection uint)
    (confidence-level uint))
    (let 
        (
            (knowledge (unwrap! (map-get? knowledge-entries { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (overall-quality (/ (+ originality-score factual-accuracy completeness-score 
                                   clarity-score relevance-score) u5))
        )
        ;; For MVP, anyone can submit AI analysis (in production, restrict to AI oracle)
        (asserts! (is-eq (get status knowledge) STATUS_AI_ANALYZING) ERR_AI_ANALYSIS_PENDING)
        (asserts! (and (<= originality-score u100) (<= factual-accuracy u100) 
                      (<= completeness-score u100) (<= clarity-score u100)
                      (<= relevance-score u100) (<= bias-detection u100)) ERR_INVALID_PARAMETERS)
        
        (map-set ai-analysis-results { knowledge-id: knowledge-id }
            {
                originality-score: originality-score,
                factual-accuracy: factual-accuracy,
                completeness-score: completeness-score,
                clarity-score: clarity-score,
                relevance-score: relevance-score,
                bias-detection: bias-detection,
                confidence-level: confidence-level,
                analysis-timestamp: burn-block-height
            }
        )
        
        (map-set knowledge-entries { knowledge-id: knowledge-id }
            (merge knowledge {
                ai-quality-score: overall-quality,
                ai-confidence: confidence-level,
                status: STATUS_COMMUNITY_VALIDATION
            })
        )
        (ok true)
    )
)

;; Community validates knowledge entry
(define-public (validate-knowledge
    (knowledge-id uint)
    (quality-rating uint)
    (accuracy-rating uint)
    (usefulness-rating uint)
    (feedback (string-ascii 256))
    (stake-amount uint))
    (let 
        (
            (knowledge (unwrap! (map-get? knowledge-entries { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (validator-profile (unwrap! (map-get? contributor-profiles { contributor: tx-sender }) ERR_UNAUTHORIZED))
            (new-validation-id (+ (var-get validation-counter) u1))
            (validator-tokens (default-to { balance: u0 } 
                (map-get? knowledge-tokens { holder: tx-sender })))
        )
        (asserts! (is-eq (get status knowledge) STATUS_COMMUNITY_VALIDATION) ERR_VALIDATION_CLOSED)
        (asserts! (not (is-eq tx-sender (get contributor knowledge))) ERR_UNAUTHORIZED)
        (asserts! (and (<= quality-rating u5) (<= accuracy-rating u5) (<= usefulness-rating u5)) ERR_INVALID_PARAMETERS)
        (asserts! (>= (get balance validator-tokens) stake-amount) ERR_INSUFFICIENT_TOKENS)
        (asserts! (> stake-amount u0) ERR_INVALID_PARAMETERS)
        
        ;; Stake tokens for validation
        (map-set knowledge-tokens { holder: tx-sender }
            { balance: (- (get balance validator-tokens) stake-amount) })
        
        (map-set knowledge-validations { validation-id: new-validation-id }
            {
                knowledge-id: knowledge-id,
                validator: tx-sender,
                quality-rating: quality-rating,
                accuracy-rating: accuracy-rating,
                usefulness-rating: usefulness-rating,
                feedback: feedback,
                validation-stake: stake-amount,
                reward-claimed: false,
                validated-at: burn-block-height
            }
        )
        
        ;; Update knowledge entry with validation
        (let ((avg-rating (/ (+ quality-rating accuracy-rating usefulness-rating) u3)))
            (map-set knowledge-entries { knowledge-id: knowledge-id }
                (merge knowledge {
                    community-votes-for: (if (>= avg-rating u3) 
                                            (+ (get community-votes-for knowledge) u1)
                                            (get community-votes-for knowledge)),
                    community-votes-against: (if (< avg-rating u3) 
                                               (+ (get community-votes-against knowledge) u1)
                                               (get community-votes-against knowledge)),
                    total-validators: (+ (get total-validators knowledge) u1)
                })
            )
        )
        
        ;; Update validator stats
        (map-set contributor-profiles { contributor: tx-sender }
            (merge validator-profile {
                validations-performed: (+ (get validations-performed validator-profile) u1)
            })
        )
        
        (var-set validation-counter new-validation-id)
        (ok new-validation-id)
    )
)

;; Finalize knowledge validation and distribute rewards
(define-public (finalize-knowledge-validation (knowledge-id uint))
    (let 
        (
            (knowledge (unwrap! (map-get? knowledge-entries { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (total-votes (+ (get community-votes-for knowledge) (get community-votes-against knowledge)))
            (approval-rate (if (> total-votes u0) 
                             (/ (* (get community-votes-for knowledge) u100) total-votes) 
                             u0))
        )
        (asserts! (is-eq (get status knowledge) STATUS_COMMUNITY_VALIDATION) ERR_VALIDATION_CLOSED)
        (asserts! (>= total-votes u3) ERR_INVALID_PARAMETERS) ;; Minimum 3 validators
        (asserts! (> burn-block-height (+ (get created-at knowledge) (var-get validation-period))) ERR_VALIDATION_CLOSED)
        
        (let 
            (
                (is-validated (>= approval-rate u60)) ;; 60% approval threshold
                (quality-multiplier (if (>= (get ai-quality-score knowledge) u80) u3 
                                    (if (>= (get ai-quality-score knowledge) u60) u2 u1)))
                (base-reward (* u100 quality-multiplier))
                (contributor-reward (if is-validated base-reward u0))
            )
            ;; Update knowledge status
            (map-set knowledge-entries { knowledge-id: knowledge-id }
                (merge knowledge {
                    status: (if is-validated STATUS_VALIDATED STATUS_REJECTED),
                    token-rewards: contributor-reward,
                    validated-at: (some burn-block-height)
                })
            )
            
            ;; Reward contributor if validated
            (if is-validated
                (let 
                    (
                        (contributor-tokens (default-to { balance: u0 } 
                            (map-get? knowledge-tokens { holder: (get contributor knowledge) })))
                        (contributor-profile (unwrap-panic 
                            (map-get? contributor-profiles { contributor: (get contributor knowledge) })))
                    )
                    (map-set knowledge-tokens { holder: (get contributor knowledge) }
                        { balance: (+ (get balance contributor-tokens) contributor-reward) })
                    
                    (map-set contributor-profiles { contributor: (get contributor knowledge) }
                        (merge contributor-profile {
                            reputation-score: (+ (get reputation-score contributor-profile) u10),
                            tokens-earned: (+ (get tokens-earned contributor-profile) contributor-reward)
                        }))
                    true
                )
                true
            )
            (ok is-validated)
        )
    )
)

;; Access knowledge and pay tokens
(define-public (access-knowledge (knowledge-id uint) (token-payment uint))
    (let 
        (
            (knowledge (unwrap! (map-get? knowledge-entries { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (accessor-tokens (default-to { balance: u0 } 
                (map-get? knowledge-tokens { holder: tx-sender })))
            (access-log (default-to { access-count: u0, last-accessed: u0, tokens-paid: u0 }
                (map-get? knowledge-access-log { knowledge-id: knowledge-id, accessor: tx-sender })))
        )
        (asserts! (is-eq (get status knowledge) STATUS_VALIDATED) ERR_KNOWLEDGE_NOT_FOUND)
        (asserts! (>= (get balance accessor-tokens) token-payment) ERR_INSUFFICIENT_TOKENS)
        
        ;; Pay tokens to contributor
        (map-set knowledge-tokens { holder: tx-sender }
            { balance: (- (get balance accessor-tokens) token-payment) })
        
        (let 
            (
                (contributor-tokens (default-to { balance: u0 } 
                    (map-get? knowledge-tokens { holder: (get contributor knowledge) })))
                (platform-fee (/ (* token-payment (var-get platform-fee-percentage)) u100))
                (contributor-payment (- token-payment platform-fee))
            )
            (map-set knowledge-tokens { holder: (get contributor knowledge) }
                { balance: (+ (get balance contributor-tokens) contributor-payment) })
        )
        
        ;; Update access log
        (map-set knowledge-access-log { knowledge-id: knowledge-id, accessor: tx-sender }
            {
                access-count: (+ (get access-count access-log) u1),
                last-accessed: burn-block-height,
                tokens-paid: (+ (get tokens-paid access-log) token-payment)
            }
        )
        
        ;; Update knowledge access count
        (map-set knowledge-entries { knowledge-id: knowledge-id }
            (merge knowledge { access-count: (+ (get access-count knowledge) u1) })
        )
        
        (ok (get content-hash knowledge))
    )
)

;; Expert endorsement system
(define-public (endorse-knowledge 
    (knowledge-id uint) 
    (endorsement-weight uint)
    (expertise-relevance uint))
    (let 
        (
            (knowledge (unwrap! (map-get? knowledge-entries { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (endorser-profile (unwrap! (map-get? contributor-profiles { contributor: tx-sender }) ERR_UNAUTHORIZED))
        )
        (asserts! (is-eq (get status knowledge) STATUS_VALIDATED) ERR_KNOWLEDGE_NOT_FOUND)
        (asserts! (>= (get reputation-score endorser-profile) u50) ERR_INSUFFICIENT_REPUTATION)
        (asserts! (and (<= endorsement-weight u10) (<= expertise-relevance u10)) ERR_INVALID_PARAMETERS)
        
        (map-set expert-endorsements { knowledge-id: knowledge-id, expert: tx-sender }
            {
                endorsement-weight: endorsement-weight,
                expertise-relevance: expertise-relevance,
                endorsed-at: burn-block-height
            }
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-knowledge (knowledge-id uint))
    (map-get? knowledge-entries { knowledge-id: knowledge-id })
)

(define-read-only (get-contributor-profile (contributor principal))
    (map-get? contributor-profiles { contributor: contributor })
)

(define-read-only (get-knowledge-tokens (holder principal))
    (map-get? knowledge-tokens { holder: holder })
)

(define-read-only (get-ai-analysis (knowledge-id uint))
    (map-get? ai-analysis-results { knowledge-id: knowledge-id })
)

(define-read-only (get-validation (validation-id uint))
    (map-get? knowledge-validations { validation-id: validation-id })
)

(define-read-only (get-knowledge-counter)
    (var-get knowledge-counter)
)

(define-read-only (get-validation-counter)
    (var-get validation-counter)
)

(define-read-only (get-platform-stats)
    {
        total-knowledge: (var-get knowledge-counter),
        total-validations: (var-get validation-counter),
        total-tokens: (var-get total-knowledge-tokens),
        platform-fee: (var-get platform-fee-percentage)
    }
)

;; Admin functions (contract owner only)
(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee u10) ERR_INVALID_PARAMETERS) ;; Max 10% fee
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-public (update-reputation-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set min-reputation-threshold new-threshold)
        (ok true)
    )
)

(define-public (mint-knowledge-tokens (recipient principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (let 
            (
                (current-tokens (default-to { balance: u0 } 
                    (map-get? knowledge-tokens { holder: recipient })))
            )
            (map-set knowledge-tokens { holder: recipient }
                { balance: (+ (get balance current-tokens) amount) })
            (var-set total-knowledge-tokens (+ (var-get total-knowledge-tokens) amount))
            (ok true)
        )
    )
)