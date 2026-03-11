;;;; package.lisp
;;;;
;;;; Package definition for Data Availability Sampling library.
;;;;
;;;; This library implements DAS for blob data verification without requiring
;;;; full data download. Uses 2D Reed-Solomon erasure coding to enable
;;;; efficient random sampling and data reconstruction.
;;;;
;;;; Key Features:
;;;;   - 2D Reed-Solomon erasure coding for blob data
;;;;   - Random sampling protocol with cryptographic security
;;;;   - Sample recovery and data reconstruction
;;;;   - Light client verification support
;;;;
;;;; Security Properties:
;;;;   - Soundness: If >50% data available, reconstruction succeeds with high prob
;;;;   - Sampling Security: k samples provide 1-(1/2)^k confidence
;;;;   - Reconstruction: Any 50% of rows/cols enables full recovery

(defpackage #:cl-data-availability-sampling
  (:use #:cl)
  (:nicknames #:das)
  (:documentation "Data Availability Sampling with 2D Reed-Solomon erasure codes.

This library implements DAS for verifying data availability without requiring
full data download. It uses 2D erasure coding to enable efficient random
sampling and data reconstruction.

Main Components:
- FIELD: Finite field arithmetic for Reed-Solomon
- REED-SOLOMON: 2D RS encoding and decoding
- SAMPLING: Random sampling protocol with confidence levels
- DAS: Main interface and data reconstruction

Usage Example:
  ;; Encode blob data for DAS
  (let* ((matrix (encode-2d-erasure blob-data))
         (blob-hash (compute-blob-hash blob-data)))
    ;; Sample for availability
    (multiple-value-bind (available-p confidence)
        (sample-data-availability matrix blob-hash slot)
      (format t \"Data available: ~A (confidence: ~,2F)~%\"
              available-p confidence)))")

  (:export
   ;; =========================================================================
   ;; Core Types - DAS Sample
   ;; =========================================================================
   #:das-sample
   #:make-das-sample
   #:das-sample-p
   #:das-sample-row
   #:das-sample-column
   #:das-sample-data
   #:das-sample-proof
   #:das-sample-verified-p
   #:das-sample-timestamp

   ;; =========================================================================
   ;; Core Types - Extended Matrix
   ;; =========================================================================
   #:extended-matrix
   #:extended-matrix-p
   #:extended-matrix-data
   #:extended-matrix-row-commitments
   #:extended-matrix-column-commitments
   #:extended-matrix-original-rows
   #:extended-matrix-original-cols
   #:extended-matrix-extended-rows
   #:extended-matrix-extended-cols
   #:extended-matrix-blob-hash

   ;; =========================================================================
   ;; Finite Field Operations
   ;; =========================================================================
   #:field-add
   #:field-sub
   #:field-mul
   #:field-div
   #:field-inv
   #:field-exp
   #:compute-root-of-unity

   ;; =========================================================================
   ;; 2D Reed-Solomon Erasure Coding
   ;; =========================================================================
   #:encode-2d-erasure
   #:decode-2d-erasure
   #:extend-row
   #:extend-column
   #:reed-solomon-encode
   #:reed-solomon-decode

   ;; =========================================================================
   ;; Random Sampling Protocol
   ;; =========================================================================
   #:generate-sample-indices
   #:sample-data-availability
   #:verify-samples
   #:compute-sampling-confidence
   #:required-samples-for-confidence

   ;; =========================================================================
   ;; Sample Recovery
   ;; =========================================================================
   #:recover-from-samples
   #:interpolate-missing-samples
   #:verify-recovered-data
   #:estimate-recovery-probability

   ;; =========================================================================
   ;; Data Reconstruction
   ;; =========================================================================
   #:reconstruct-blob
   #:reconstruct-row
   #:reconstruct-column
   #:verify-reconstruction
   #:partial-reconstruction

   ;; =========================================================================
   ;; Blob Integration
   ;; =========================================================================
   #:blob-to-extended-matrix
   #:extended-matrix-to-blob
   #:verify-blob-availability
   #:sample-blob-data

   ;; =========================================================================
   ;; Configuration
   ;; =========================================================================
   #:*das-config*
   #:das-config
   #:make-das-config
   #:das-config-p
   #:das-config-samples-per-slot
   #:das-config-reconstruction-threshold

   ;; =========================================================================
   ;; Constants
   ;; =========================================================================
   #:+das-rows+
   #:+das-columns+
   #:+extended-rows+
   #:+extended-columns+
   #:+field-element-bytes+
   #:+samples-for-95-confidence+
   #:+samples-for-99-confidence+
   #:+reconstruction-threshold+

   ;; =========================================================================
   ;; Utility Functions
   ;; =========================================================================
   #:sha256
   #:bytes-to-integer
   #:integer-to-bytes
   #:compute-merkle-root))
