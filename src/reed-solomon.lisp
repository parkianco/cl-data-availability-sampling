;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; reed-solomon.lisp
;;;;
;;;; 2D Reed-Solomon erasure coding for Data Availability Sampling.
;;;;
;;;; Implements 2D erasure codes where data is arranged in a matrix and
;;;; extended in both dimensions. Any 50% of rows or columns allows
;;;; complete reconstruction via polynomial interpolation.
;;;;
;;;; Mathematical Foundation:
;;;;   Given data D arranged as n x n matrix, extend to 2n x 2n by treating
;;;;   each row and column as evaluations of degree-(n-1) polynomials.
;;;;   Extend each polynomial to 2n evaluation points.

(in-package #:cl-data-availability-sampling)

;;; ============================================================================
;;; CONSTANTS
;;; ============================================================================

(defconstant +das-rows+ 64
  "Number of rows in original data matrix (before extension).")

(defconstant +das-columns+ 64
  "Number of columns in original data matrix (before extension).")

(defconstant +extended-rows+ 128
  "Number of rows after 2D erasure code extension (2x original).")

(defconstant +extended-columns+ 128
  "Number of columns after 2D erasure code extension (2x original).")

(defconstant +field-element-bytes+ 32
  "Size of each field element in bytes.")

(defconstant +reconstruction-threshold+ 0.5
  "Minimum fraction of data needed for successful reconstruction.")

;;; ============================================================================
;;; CORE TYPES
;;; ============================================================================

(defstruct (extended-matrix
            (:constructor make-extended-matrix-internal)
            (:copier nil))
  "2D erasure-coded matrix.
Extended from original dimensions to 2x in each direction."
  (data nil :type (or null (simple-array t (* *))))
  (row-commitments nil :type (or null vector))
  (column-commitments nil :type (or null vector))
  (original-rows +das-rows+ :type fixnum)
  (original-cols +das-columns+ :type fixnum)
  (extended-rows +extended-rows+ :type fixnum)
  (extended-cols +extended-columns+ :type fixnum)
  (blob-hash nil :type (or null (simple-array (unsigned-byte 8) (*)))))

;;; ============================================================================
;;; 2D ERASURE CODING
;;; ============================================================================

(defun encode-2d-erasure (data)
  "Encode data using 2D Reed-Solomon erasure coding.

Takes original data arranged in a 64x64 matrix and extends it to
128x128 by adding parity rows and columns. Each row and column
becomes a degree-63 polynomial evaluated at 128 points.

Arguments:
  DATA - Original data as 64x64 matrix or flat vector

Returns:
  EXTENDED-MATRIX structure with full 128x128 encoded data

Example:
  (encode-2d-erasure blob-data)"
  (let* ((matrix (ensure-matrix-form data))
         (extended (make-array (list +extended-rows+ +extended-columns+)
                               :initial-element nil)))
    ;; Step 1: Copy original data to top-left quadrant
    (dotimes (row +das-rows+)
      (dotimes (col +das-columns+)
        (setf (aref extended row col)
              (aref matrix row col))))

    ;; Step 2: Extend each row to the right (add parity columns)
    (dotimes (row +das-rows+)
      (let* ((row-data (extract-row matrix row))
             (extended-row (reed-solomon-encode row-data +extended-columns+)))
        (loop for col from +das-columns+ below +extended-columns+
              do (setf (aref extended row col)
                       (aref extended-row col)))))

    ;; Step 3: Extend each column downward (add parity rows)
    (dotimes (col +extended-columns+)
      (let* ((col-data (extract-column extended col +das-rows+))
             (extended-col (reed-solomon-encode col-data +extended-rows+)))
        (loop for row from +das-rows+ below +extended-rows+
              do (setf (aref extended row col)
                       (aref extended-col row)))))

    ;; Step 4: Compute commitments
    (let ((row-commitments (compute-row-commitments extended))
          (col-commitments (compute-column-commitments extended)))
      (make-extended-matrix-internal
       :data extended
       :row-commitments row-commitments
       :column-commitments col-commitments
       :original-rows +das-rows+
       :original-cols +das-columns+))))

(defun decode-2d-erasure (matrix available-samples)
  "Decode original data from partial samples using 2D erasure decoding.

If at least 50% of any row or column is available, we can reconstruct
the full row/column using polynomial interpolation.

Arguments:
  MATRIX - Extended matrix structure (possibly with missing data)
  AVAILABLE-SAMPLES - List of DAS-SAMPLE structures

Returns:
  Reconstructed original data, or NIL if reconstruction fails"
  (declare (ignore matrix))
  (let ((recovered (make-array (list +extended-rows+ +extended-columns+)
                               :initial-element nil)))
    ;; Mark available positions
    (dolist (sample available-samples)
      (setf (aref recovered (das-sample-row sample) (das-sample-column sample))
            (das-sample-data sample)))

    ;; Try to recover each row
    (dotimes (row +extended-rows+)
      (let ((available-count (count-available-in-row recovered row)))
        (when (>= available-count (/ +extended-columns+ 2))
          (reconstruct-row recovered row))))

    ;; Try to recover each column
    (dotimes (col +extended-columns+)
      (let ((available-count (count-available-in-column recovered col)))
        (when (>= available-count (/ +extended-rows+ 2))
          (reconstruct-column recovered col))))

    ;; Extract original data
    (when (verify-reconstruction recovered)
      (extract-original-data recovered))))

;;; ============================================================================
;;; REED-SOLOMON ENCODING/DECODING
;;; ============================================================================

(defun element-to-integer (element)
  "Convert a data element to an integer for field arithmetic."
  (cond ((integerp element) element)
        ((null element) 0)
        ((typep element '(vector (unsigned-byte 8)))
         (bytes-to-integer element))
        ((vectorp element)
         (bytes-to-integer (coerce element '(vector (unsigned-byte 8)))))
        (t 0)))

(defun reed-solomon-encode (data-vector target-length)
  "Encode data using Reed-Solomon code to target length.

Treats input as polynomial evaluations and extends to more points.

Arguments:
  DATA-VECTOR - Original data points
  TARGET-LENGTH - Desired output length (must be >= input length)

Returns:
  Extended data vector"
  (let* ((n (length data-vector))
         ;; Convert elements to integers for field arithmetic
         (int-data (make-array n))
         (_ (dotimes (i n)
              (setf (aref int-data i) (element-to-integer (aref data-vector i)))))
         (coefficients (fft-inverse int-data))
         (result (make-array target-length)))
    (declare (ignore _))
    ;; Evaluate polynomial at all target points
    (dotimes (i target-length result)
      (if (< i n)
          (setf (aref result i) (aref data-vector i))
          (let ((omega (compute-root-of-unity i target-length)))
            (setf (aref result i)
                  (evaluate-polynomial coefficients omega)))))))

(defun reed-solomon-decode (samples positions original-length)
  "Decode Reed-Solomon code from partial samples.

Arguments:
  SAMPLES - Available data samples
  POSITIONS - Positions of available samples
  ORIGINAL-LENGTH - Original data length

Returns:
  Recovered original data vector"
  (when (< (length samples) original-length)
    (error "Insufficient samples for Reed-Solomon decoding"))
  ;; Use Lagrange interpolation to recover polynomial
  (let* ((coefficients (lagrange-interpolate samples positions))
         (result (make-array original-length)))
    (dotimes (i original-length result)
      (let ((omega (compute-root-of-unity i original-length)))
        (setf (aref result i)
              (evaluate-polynomial coefficients omega))))))

;;; ============================================================================
;;; HELPER FUNCTIONS
;;; ============================================================================

(defun ensure-matrix-form (data)
  "Convert data to 64x64 matrix form if needed."
  (if (arrayp data)
      (if (= (array-rank data) 2)
          data
          (reshape-to-matrix data +das-rows+ +das-columns+))
      (error "Invalid data format for erasure encoding")))

(defun reshape-to-matrix (flat-data rows cols)
  "Reshape flat data into rows x cols matrix."
  (let ((matrix (make-array (list rows cols))))
    (dotimes (r rows matrix)
      (dotimes (c cols)
        (let ((idx (* (+ (* r cols) c) +field-element-bytes+)))
          (if (< (+ idx +field-element-bytes+) (length flat-data))
              (setf (aref matrix r c)
                    (subseq flat-data idx (+ idx +field-element-bytes+)))
              (setf (aref matrix r c)
                    (make-array +field-element-bytes+
                                :element-type '(unsigned-byte 8)
                                :initial-element 0))))))))

(defun extract-row (matrix row)
  "Extract a single row from matrix as vector."
  (let* ((cols (array-dimension matrix 1))
         (result (make-array cols)))
    (dotimes (c cols result)
      (setf (aref result c) (aref matrix row c)))))

(defun extract-column (matrix col &optional (rows nil))
  "Extract a single column from matrix as vector."
  (let* ((actual-rows (or rows (array-dimension matrix 0)))
         (result (make-array actual-rows)))
    (dotimes (r actual-rows result)
      (setf (aref result r) (aref matrix r col)))))

(defun row-to-polynomial (row-data)
  "Convert row data to polynomial coefficients via IFFT."
  (fft-inverse row-data))

(defun fft-inverse (data)
  "Inverse FFT: evaluations to coefficients.
This is a simplified placeholder - full implementation would use FFT."
  (copy-seq data))

(defun compute-row-commitments (matrix)
  "Compute commitments for each row of the extended matrix.

Arguments:
  MATRIX - 2D array of field elements

Returns:
  Vector of commitments, one per row"
  (let* ((rows (array-dimension matrix 0))
         (commitments (make-array rows)))
    (dotimes (row rows commitments)
      (let ((row-data (extract-row matrix row)))
        (setf (aref commitments row)
              (compute-commitment row-data))))))

(defun compute-column-commitments (matrix)
  "Compute commitments for each column of the extended matrix.

Arguments:
  MATRIX - 2D array of field elements

Returns:
  Vector of commitments, one per column"
  (let* ((cols (array-dimension matrix 1))
         (commitments (make-array cols)))
    (dotimes (col cols commitments)
      (let ((col-data (extract-column matrix col)))
        (setf (aref commitments col)
              (compute-commitment col-data))))))

(defun element-to-bytes (element)
  "Convert a data element to a byte array."
  (cond ((null element)
         (make-array +field-element-bytes+ :element-type '(unsigned-byte 8)
                                           :initial-element 0))
        ((integerp element)
         (integer-to-bytes element +field-element-bytes+))
        ((typep element '(simple-array (unsigned-byte 8) (*)))
         element)
        ((vectorp element)
         (coerce element '(simple-array (unsigned-byte 8) (*))))
        (t (make-array +field-element-bytes+ :element-type '(unsigned-byte 8)
                                             :initial-element 0))))

(defun compute-commitment (data)
  "Compute a commitment to data (simplified hash-based commitment)."
  (sha256 (if (vectorp data)
              (apply #'concatenate '(vector (unsigned-byte 8))
                     (map 'list #'element-to-bytes data))
              (element-to-bytes data))))

;;; ============================================================================
;;; COUNTING HELPERS
;;; ============================================================================

(defun count-available-in-row (matrix row)
  "Count non-NIL elements in a row."
  (let ((count 0))
    (dotimes (col (array-dimension matrix 1) count)
      (when (aref matrix row col)
        (incf count)))))

(defun count-available-in-column (matrix col)
  "Count non-NIL elements in a column."
  (let ((count 0))
    (dotimes (row (array-dimension matrix 0) count)
      (when (aref matrix row col)
        (incf count)))))

(defun count-all-available (matrix)
  "Count all non-NIL elements in matrix."
  (let ((count 0))
    (dotimes (row (array-dimension matrix 0) count)
      (dotimes (col (array-dimension matrix 1))
        (when (aref matrix row col)
          (incf count))))))

(defun extract-original-data (matrix)
  "Extract original data region from extended matrix."
  (let ((result (make-array (list +das-rows+ +das-columns+))))
    (dotimes (row +das-rows+ result)
      (dotimes (col +das-columns+)
        (setf (aref result row col) (aref matrix row col))))))
