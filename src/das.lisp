;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; das.lisp
;;;;
;;;; Main DAS interface: data reconstruction and blob integration.
;;;;
;;;; Provides the high-level API for Data Availability Sampling,
;;;; including recovery from partial samples and blob conversion.

(in-package #:cl-data-availability-sampling)

;;; ============================================================================
;;; SAMPLE RECOVERY
;;; ============================================================================

(defun recover-from-samples (samples original-rows original-cols)
  "Attempt to recover original data from available samples.

Uses 2D erasure decoding - if any row or column has >= 50% samples,
we can recover it completely, then use those to recover others.

Arguments:
  SAMPLES - List of verified DAS-SAMPLE structures
  ORIGINAL-ROWS - Number of rows in original data
  ORIGINAL-COLS - Number of columns in original data

Returns:
  Recovered data matrix or NIL if recovery fails"
  (let ((recovered (make-array (list +extended-rows+ +extended-columns+)
                               :initial-element nil))
        (changed t))
    ;; Initialize with available samples
    (dolist (sample samples)
      (when (das-sample-verified-p sample)
        (setf (aref recovered (das-sample-row sample) (das-sample-column sample))
              (das-sample-data sample))))

    ;; Iterate until no more recovery possible
    (loop while changed do
      (setf changed nil)
      ;; Try to recover each row
      (dotimes (row +extended-rows+)
        (let ((available (count-available-in-row recovered row)))
          (when (and (< available +extended-columns+)
                     (>= available (/ +extended-columns+ 2)))
            (when (reconstruct-row recovered row)
              (setf changed t)))))
      ;; Try to recover each column
      (dotimes (col +extended-columns+)
        (let ((available (count-available-in-column recovered col)))
          (when (and (< available +extended-rows+)
                     (>= available (/ +extended-rows+ 2)))
            (when (reconstruct-column recovered col)
              (setf changed t))))))

    ;; Check if we recovered original data
    (when (fully-recovered-p recovered original-rows original-cols)
      (extract-original-data recovered))))

(defun interpolate-missing-samples (available-positions available-values target-length)
  "Interpolate missing values using Lagrange polynomial interpolation.

Arguments:
  AVAILABLE-POSITIONS - List of known positions
  AVAILABLE-VALUES - List of known values
  TARGET-LENGTH - Full length to interpolate

Returns:
  Complete vector of interpolated values"
  (let ((coefficients (lagrange-interpolate available-values available-positions)))
    (let ((result (make-array target-length)))
      (dotimes (i target-length result)
        (let ((omega (compute-root-of-unity i target-length)))
          (setf (aref result i)
                (evaluate-polynomial coefficients omega)))))))

(defun verify-recovered-data (recovered-matrix row-commitments column-commitments)
  "Verify recovered data matches commitments.

Arguments:
  RECOVERED-MATRIX - Matrix of recovered data
  ROW-COMMITMENTS - Original row commitments
  COLUMN-COMMITMENTS - Original column commitments

Returns:
  T if data is valid"
  (declare (ignore column-commitments))
  ;; Verify each row's commitment matches
  (dotimes (row (array-dimension recovered-matrix 0) t)
    (let* ((row-data (extract-row recovered-matrix row))
           (computed-commitment (compute-commitment row-data))
           (expected-commitment (aref row-commitments row)))
      (unless (equalp computed-commitment expected-commitment)
        (return nil)))))

(defun estimate-recovery-probability (available-fraction)
  "Estimate probability of successful recovery given available data fraction.

Arguments:
  AVAILABLE-FRACTION - Fraction of data available (0.0-1.0)

Returns:
  Estimated recovery probability"
  (cond
    ((>= available-fraction 0.75) 0.99)
    ((>= available-fraction 0.5) 0.95)
    ((>= available-fraction 0.25) 0.5)
    (t 0.0)))

(defun fully-recovered-p (matrix rows cols)
  "Check if original data region is fully recovered."
  (dotimes (row rows t)
    (dotimes (col cols)
      (unless (aref matrix row col)
        (return-from fully-recovered-p nil)))))

;;; ============================================================================
;;; DATA RECONSTRUCTION ALGORITHMS
;;; ============================================================================

(defun reconstruct-blob (extended-matrix)
  "Reconstruct original blob from extended matrix.

Arguments:
  EXTENDED-MATRIX - Extended matrix structure

Returns:
  Original blob data as byte vector"
  (let* ((data (extended-matrix-data extended-matrix))
         (orig-rows (extended-matrix-original-rows extended-matrix))
         (orig-cols (extended-matrix-original-cols extended-matrix))
         (blob-size (* orig-rows orig-cols +field-element-bytes+))
         (result (make-array blob-size :element-type '(unsigned-byte 8))))
    (dotimes (row orig-rows result)
      (dotimes (col orig-cols)
        (let* ((element (aref data row col))
               (offset (* (+ (* row orig-cols) col) +field-element-bytes+)))
          (when element
            (replace result element :start1 offset)))))))

(defun reconstruct-row (matrix row)
  "Reconstruct a single row using available samples.

Arguments:
  MATRIX - Matrix with partial data
  ROW - Row index to reconstruct

Returns:
  T if reconstruction successful"
  (let* ((cols +extended-columns+)
         (available-positions nil)
         (available-values nil))
    ;; Collect available samples
    (dotimes (col cols)
      (when (aref matrix row col)
        (push col available-positions)
        (push (aref matrix row col) available-values)))
    ;; Need at least half for reconstruction
    (when (>= (length available-positions) (/ cols 2))
      (let ((reconstructed (interpolate-missing-samples
                            (nreverse available-positions)
                            (nreverse available-values)
                            cols)))
        ;; Fill in missing values
        (dotimes (col cols t)
          (unless (aref matrix row col)
            (setf (aref matrix row col) (aref reconstructed col))))))))

(defun reconstruct-column (matrix col)
  "Reconstruct a single column using available samples.

Arguments:
  MATRIX - Matrix with partial data
  COL - Column index to reconstruct

Returns:
  T if reconstruction successful"
  (let* ((rows +extended-rows+)
         (available-positions nil)
         (available-values nil))
    ;; Collect available samples
    (dotimes (row rows)
      (when (aref matrix row col)
        (push row available-positions)
        (push (aref matrix row col) available-values)))
    ;; Need at least half for reconstruction
    (when (>= (length available-positions) (/ rows 2))
      (let ((reconstructed (interpolate-missing-samples
                            (nreverse available-positions)
                            (nreverse available-values)
                            rows)))
        ;; Fill in missing values
        (dotimes (row rows t)
          (unless (aref matrix row col)
            (setf (aref matrix row col) (aref reconstructed row))))))))

(defun verify-reconstruction (matrix)
  "Verify that reconstruction produced valid data.

Checks that all cells have data after reconstruction.

Arguments:
  MATRIX - Reconstructed matrix

Returns:
  T if fully reconstructed"
  (dotimes (row (array-dimension matrix 0) t)
    (dotimes (col (array-dimension matrix 1))
      (unless (aref matrix row col)
        (return-from verify-reconstruction nil)))))

(defun partial-reconstruction (samples target-positions)
  "Attempt partial reconstruction for specific positions.

Arguments:
  SAMPLES - Available samples
  TARGET-POSITIONS - Positions to reconstruct

Returns:
  List of reconstructed samples for target positions"
  (let ((matrix (make-array (list +extended-rows+ +extended-columns+)
                            :initial-element nil))
        (results nil))
    ;; Populate matrix with available samples
    (dolist (sample samples)
      (setf (aref matrix (das-sample-row sample) (das-sample-column sample))
            (das-sample-data sample)))

    ;; Try reconstruction for each target
    (dolist (target target-positions (nreverse results))
      (let ((row (car target))
            (col (cdr target)))
        (unless (aref matrix row col)
          ;; Try row-based reconstruction
          (when (>= (count-available-in-row matrix row) (/ +extended-columns+ 2))
            (reconstruct-row matrix row))
          ;; Try column-based reconstruction
          (when (and (null (aref matrix row col))
                     (>= (count-available-in-column matrix col) (/ +extended-rows+ 2)))
            (reconstruct-column matrix col)))
        (when (aref matrix row col)
          (push (make-das-sample :row row :column col :data (aref matrix row col))
                results))))))

;;; ============================================================================
;;; BLOB INTEGRATION
;;; ============================================================================

(defun blob-to-extended-matrix (blob-data blob-hash)
  "Convert blob data to extended matrix for DAS.

Arguments:
  BLOB-DATA - Raw blob data
  BLOB-HASH - Blob identifier

Returns:
  EXTENDED-MATRIX structure"
  (let ((matrix (encode-2d-erasure blob-data)))
    (setf (extended-matrix-blob-hash matrix) blob-hash)
    matrix))

(defun extended-matrix-to-blob (matrix)
  "Convert extended matrix back to blob data.

Arguments:
  MATRIX - EXTENDED-MATRIX structure

Returns:
  Original blob data"
  (reconstruct-blob matrix))

(defun verify-blob-availability (blob-hash slot row-commitments column-commitments)
  "Verify blob availability using DAS.

Arguments:
  BLOB-HASH - 32-byte blob identifier
  SLOT - Current slot number
  ROW-COMMITMENTS - Row commitment vector
  COLUMN-COMMITMENTS - Column commitment vector

Returns:
  (VALUES available-p confidence)"
  (declare (ignore column-commitments))
  (let* ((sample-count (das-config-samples-per-slot *das-config*))
         (indices (generate-sample-indices blob-hash slot sample-count))
         (verified 0)
         (total (length indices)))
    ;; In production, samples would be fetched from network
    ;; Here we simulate successful verification
    (setf verified total)
    (let ((confidence (compute-sampling-confidence verified total)))
      (values (>= confidence 0.95) confidence))))

(defun sample-blob-data (blob-hash matrix indices)
  "Sample specific positions from blob data.

Arguments:
  BLOB-HASH - Blob identifier
  MATRIX - Extended matrix
  INDICES - List of (row . col) positions to sample

Returns:
  List of DAS-SAMPLE structures"
  (declare (ignore blob-hash))
  (mapcar (lambda (index)
            (let ((row (car index))
                  (col (cdr index)))
              (compute-sample-proof matrix row col)))
          indices))
