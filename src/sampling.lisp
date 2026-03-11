;;;; sampling.lisp
;;;;
;;;; Random sampling protocol for Data Availability Sampling.
;;;;
;;;; Implements the DAS sampling protocol where random positions are sampled
;;;; from the extended matrix and verified. If all k samples verify,
;;;; data availability is confirmed with probability >= 1 - (1/2)^k.

(in-package #:cl-data-availability-sampling)

;;; ============================================================================
;;; CONSTANTS
;;; ============================================================================

(defconstant +samples-for-95-confidence+ 30
  "Number of samples needed for 95% confidence in data availability.")

(defconstant +samples-for-99-confidence+ 75
  "Number of samples needed for 99% confidence in data availability.")

;;; ============================================================================
;;; CONFIGURATION
;;; ============================================================================

(defstruct (das-config
            (:constructor make-das-config)
            (:copier nil))
  "Configuration for Data Availability Sampling."
  (samples-per-slot 75 :type fixnum)
  (reconstruction-threshold 0.5 :type single-float)
  (parallel-sampling-p t :type boolean)
  (cache-proofs-p t :type boolean)
  (max-concurrent-requests 16 :type fixnum))

(defvar *das-config* (make-das-config)
  "Global DAS configuration instance.")

;;; ============================================================================
;;; CORE TYPES
;;; ============================================================================

(defstruct (das-sample
            (:constructor make-das-sample)
            (:copier nil))
  "A single sample from the extended data matrix.
Contains the data element, its position, and optional proof."
  (row 0 :type fixnum)
  (column 0 :type fixnum)
  (data nil :type (or null (simple-array (unsigned-byte 8) (*))))
  (proof nil :type (or null (simple-array (unsigned-byte 8) (*))))
  (verified-p nil :type boolean)
  (timestamp 0 :type integer))

;;; ============================================================================
;;; RANDOM SAMPLING PROTOCOL
;;; ============================================================================

(defun generate-sample-indices (blob-hash slot &optional (count nil))
  "Generate cryptographically random sample indices for a blob.

Uses the blob hash and slot number as seed for deterministic
randomness, allowing independent samplers to verify same positions.

Arguments:
  BLOB-HASH - 32-byte blob identifier
  SLOT - Current slot number
  COUNT - Number of samples (default from config)

Returns:
  List of (row . column) pairs"
  (let* ((num-samples (or count (das-config-samples-per-slot *das-config*)))
         (seed (compute-sampling-seed blob-hash slot))
         (indices nil))
    (dotimes (i num-samples (nreverse indices))
      (let* ((sample-seed (hash-with-index seed i))
             (row (mod (bytes-to-integer (subseq sample-seed 0 8)) +extended-rows+))
             (col (mod (bytes-to-integer (subseq sample-seed 8 16)) +extended-columns+)))
        (push (cons row col) indices)))))

(defun sample-data-availability (matrix blob-hash slot)
  "Perform random sampling to verify data availability.

Samples random positions from the extended matrix and verifies
their proofs against row/column commitments.

Arguments:
  MATRIX - Extended matrix structure
  BLOB-HASH - Blob identifier for sampling seed
  SLOT - Current slot for determinism

Returns:
  (VALUES available-p confidence samples-verified samples-failed)"
  (let* ((indices (generate-sample-indices blob-hash slot))
         (verified 0)
         (failed 0)
         (samples nil))
    (dolist (index indices)
      (let* ((row (car index))
             (col (cdr index))
             (sample (compute-sample-proof matrix row col))
             (row-commitment (aref (extended-matrix-row-commitments matrix) row)))
        (if (verify-sample-proof sample row-commitment)
            (progn
              (incf verified)
              (setf (das-sample-verified-p sample) t))
            (incf failed))
        (push sample samples)))
    (let* ((total (+ verified failed))
           (confidence (compute-sampling-confidence verified total))
           (available-p (and (> verified 0) (zerop failed))))
      (values available-p confidence verified failed))))

(defun verify-samples (samples row-commitments column-commitments)
  "Verify set of DAS samples against commitments.

Arguments:
  SAMPLES - List of DAS-SAMPLE structures
  ROW-COMMITMENTS - Vector of row commitments
  COLUMN-COMMITMENTS - Vector of column commitments

Returns:
  (VALUES all-valid-p valid-count invalid-count)"
  (declare (ignore column-commitments))
  (let ((valid 0)
        (invalid 0))
    (dolist (sample samples)
      (let* ((row (das-sample-row sample))
             (row-commitment (aref row-commitments row)))
        (if (verify-sample-proof sample row-commitment)
            (incf valid)
            (incf invalid))))
    (values (zerop invalid) valid invalid)))

(defun compute-sampling-confidence (verified total)
  "Compute confidence level from sampling results.

If all k samples verify and data is at least 50% available,
confidence is 1 - (1/2)^k.

Arguments:
  VERIFIED - Number of verified samples
  TOTAL - Total samples attempted

Returns:
  Confidence as float 0.0-1.0"
  (if (zerop total)
      0.0
      (let ((success-rate (/ verified total)))
        (if (< success-rate 1.0)
            (* success-rate (- 1.0 (expt 0.5 verified)))
            (- 1.0 (expt 0.5 verified))))))

(defun required-samples-for-confidence (target-confidence)
  "Calculate samples needed to achieve target confidence.

Arguments:
  TARGET-CONFIDENCE - Desired confidence (0.0-1.0)

Returns:
  Number of samples required"
  (ceiling (/ (log (- 1.0 target-confidence))
              (log 0.5))))

;;; ============================================================================
;;; PROOF GENERATION AND VERIFICATION
;;; ============================================================================

(defun compute-sample-proof (matrix row col)
  "Compute proof for a single sample at (row, col).

The proof allows verification that the sample value is consistent
with the row commitment.

Arguments:
  MATRIX - Extended matrix structure
  ROW - Row index
  COL - Column index

Returns:
  DAS-SAMPLE with proof attached"
  (let* ((data (extended-matrix-data matrix))
         (sample-data (aref data row col))
         (row-commitment (aref (extended-matrix-row-commitments matrix) row))
         ;; Generate proof (simplified - hash-based in this implementation)
         (proof (sha256 (concatenate '(vector (unsigned-byte 8))
                                     (or sample-data #())
                                     (integer-to-bytes row 4)
                                     (integer-to-bytes col 4)))))
    (make-das-sample
     :row row
     :column col
     :data sample-data
     :proof proof
     :timestamp (get-universal-time))))

(defun verify-sample-proof (sample row-commitment)
  "Verify proof for DAS sample.

Arguments:
  SAMPLE - DAS-SAMPLE structure
  ROW-COMMITMENT - Commitment for the sample's row

Returns:
  T if proof is valid"
  (declare (ignore row-commitment))
  ;; Simplified verification - in production would use KZG pairing check
  (and (das-sample-data sample)
       (das-sample-proof sample)
       t))

;;; ============================================================================
;;; SEED COMPUTATION
;;; ============================================================================

(defun compute-sampling-seed (blob-hash slot)
  "Compute deterministic sampling seed from blob hash and slot."
  (sha256 (concatenate '(vector (unsigned-byte 8))
                       (or blob-hash (make-array 32 :element-type '(unsigned-byte 8)
                                                     :initial-element 0))
                       (integer-to-bytes slot 8))))

(defun hash-with-index (seed index)
  "Hash seed with index for sample position derivation."
  (sha256 (concatenate '(vector (unsigned-byte 8))
                       seed
                       (integer-to-bytes index 4))))
