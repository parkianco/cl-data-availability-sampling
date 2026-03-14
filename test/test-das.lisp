;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: BSD-3-Clause

;;;; test-das.lisp
;;;;
;;;; Tests for cl-data-availability-sampling library.

(defpackage #:cl-data-availability-sampling/test
  (:use #:cl #:cl-data-availability-sampling)
  (:export #:run-tests))

(in-package #:cl-data-availability-sampling/test)

;;; ============================================================================
;;; TEST FRAMEWORK
;;; ============================================================================

(defvar *test-count* 0)
(defvar *pass-count* 0)
(defvar *fail-count* 0)

(defmacro deftest (name &body body)
  "Define a test case."
  `(defun ,name ()
     (incf *test-count*)
     (handler-case
         (progn ,@body
                (incf *pass-count*)
                (format t "  PASS: ~A~%" ',name))
       (error (e)
         (incf *fail-count*)
         (format t "  FAIL: ~A~%        ~A~%" ',name e)))))

(defmacro assert-true (form &optional message)
  "Assert that form evaluates to true."
  `(unless ,form
     (error "Assertion failed~@[: ~A~]" ,message)))

(defmacro assert-equal (expected actual &optional message)
  "Assert that expected equals actual."
  `(unless (equal ,expected ,actual)
     (error "Expected ~S but got ~S~@[: ~A~]" ,expected ,actual ,message)))

(defmacro assert-equalp (expected actual &optional message)
  "Assert that expected equalp actual."
  `(unless (equalp ,expected ,actual)
     (error "Expected ~S but got ~S~@[: ~A~]" ,expected ,actual ,message)))

;;; ============================================================================
;;; FIELD ARITHMETIC TESTS
;;; ============================================================================

(deftest test-field-add
  (assert-equal 5 (field-add 2 3))
  (assert-equal 0 (field-add 0 0)))

(deftest test-field-mul
  (assert-equal 6 (field-mul 2 3))
  (assert-equal 0 (field-mul 0 5)))

(deftest test-field-exp
  (assert-equal 8 (field-exp 2 3))
  (assert-equal 1 (field-exp 5 0)))

(deftest test-mod-exp
  (assert-equal 8 (mod-exp 2 3 100))
  (assert-equal 1 (mod-exp 7 0 13)))

;;; ============================================================================
;;; BYTE MANIPULATION TESTS
;;; ============================================================================

(deftest test-bytes-to-integer
  (let ((bytes (make-array 4 :element-type '(unsigned-byte 8)
                             :initial-contents '(0 0 1 0))))
    (assert-equal 256 (bytes-to-integer bytes))))

(deftest test-integer-to-bytes
  (let ((result (integer-to-bytes 256 4)))
    (assert-equal 4 (length result))
    (assert-equal 0 (aref result 0))
    (assert-equal 0 (aref result 1))
    (assert-equal 1 (aref result 2))
    (assert-equal 0 (aref result 3))))

(deftest test-bytes-roundtrip
  (let* ((original 12345678)
         (bytes (integer-to-bytes original 8))
         (recovered (bytes-to-integer bytes)))
    (assert-equal original recovered)))

;;; ============================================================================
;;; SHA256 TESTS
;;; ============================================================================

(deftest test-sha256-produces-32-bytes
  (let* ((data (make-array 10 :element-type '(unsigned-byte 8) :initial-element 0))
         (hash (sha256 data)))
    (assert-equal 32 (length hash))))

(deftest test-sha256-deterministic
  (let* ((data (make-array 10 :element-type '(unsigned-byte 8) :initial-element 42))
         (hash1 (sha256 data))
         (hash2 (sha256 data)))
    (assert-equalp hash1 hash2)))

;;; ============================================================================
;;; REED-SOLOMON TESTS
;;; ============================================================================

(deftest test-encode-2d-erasure-dimensions
  (let* ((data (make-array (list +das-rows+ +das-columns+) :initial-element 0))
         (matrix (encode-2d-erasure data)))
    (assert-true (extended-matrix-p matrix))
    (assert-equal +extended-rows+ (extended-matrix-extended-rows matrix))
    (assert-equal +extended-columns+ (extended-matrix-extended-cols matrix))))

(deftest test-reed-solomon-encode-length
  (let* ((data (make-array 64 :initial-element 0))
         (encoded (reed-solomon-encode data 128)))
    (assert-equal 128 (length encoded))))

(deftest test-extract-row
  (let ((matrix (make-array '(4 4) :initial-contents
                            '((1 2 3 4) (5 6 7 8) (9 10 11 12) (13 14 15 16)))))
    (let ((row (extract-row matrix 1)))
      (assert-equal 4 (length row))
      (assert-equal 5 (aref row 0))
      (assert-equal 8 (aref row 3)))))

(deftest test-extract-column
  (let ((matrix (make-array '(4 4) :initial-contents
                            '((1 2 3 4) (5 6 7 8) (9 10 11 12) (13 14 15 16)))))
    (let ((col (extract-column matrix 2)))
      (assert-equal 4 (length col))
      (assert-equal 3 (aref col 0))
      (assert-equal 15 (aref col 3)))))

;;; ============================================================================
;;; SAMPLING TESTS
;;; ============================================================================

(deftest test-generate-sample-indices
  (let* ((blob-hash (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0))
         (indices (generate-sample-indices blob-hash 0 10)))
    (assert-equal 10 (length indices))
    (dolist (index indices)
      (assert-true (consp index))
      (assert-true (< (car index) +extended-rows+))
      (assert-true (< (cdr index) +extended-columns+)))))

(deftest test-generate-sample-indices-deterministic
  (let* ((blob-hash (make-array 32 :element-type '(unsigned-byte 8) :initial-element 1))
         (indices1 (generate-sample-indices blob-hash 5 20))
         (indices2 (generate-sample-indices blob-hash 5 20)))
    (assert-equalp indices1 indices2)))

(deftest test-compute-sampling-confidence
  (assert-equal 0.0 (compute-sampling-confidence 0 0))
  (let ((conf (compute-sampling-confidence 10 10)))
    (assert-true (> conf 0.99))))

(deftest test-required-samples-for-confidence
  (let ((samples-95 (required-samples-for-confidence 0.95))
        (samples-99 (required-samples-for-confidence 0.99)))
    (assert-true (> samples-99 samples-95))
    (assert-true (> samples-95 0))))

;;; ============================================================================
;;; DAS SAMPLE TESTS
;;; ============================================================================

(deftest test-make-das-sample
  (let ((sample (make-das-sample :row 5 :column 10)))
    (assert-true (das-sample-p sample))
    (assert-equal 5 (das-sample-row sample))
    (assert-equal 10 (das-sample-column sample))))

;;; ============================================================================
;;; CONFIG TESTS
;;; ============================================================================

(deftest test-das-config-defaults
  (let ((config (make-das-config)))
    (assert-true (das-config-p config))
    (assert-equal 75 (das-config-samples-per-slot config))
    (assert-equal 0.5 (das-config-reconstruction-threshold config))))

;;; ============================================================================
;;; MERKLE TREE TESTS
;;; ============================================================================

(deftest test-compute-merkle-root-single
  (let* ((leaf (make-array 32 :element-type '(unsigned-byte 8) :initial-element 1))
         (root (compute-merkle-root (list leaf))))
    (assert-equalp leaf root)))

(deftest test-compute-merkle-root-multiple
  (let* ((leaf1 (make-array 32 :element-type '(unsigned-byte 8) :initial-element 1))
         (leaf2 (make-array 32 :element-type '(unsigned-byte 8) :initial-element 2))
         (root (compute-merkle-root (list leaf1 leaf2))))
    (assert-equal 32 (length root))))

;;; ============================================================================
;;; RECOVERY TESTS
;;; ============================================================================

(deftest test-estimate-recovery-probability
  (assert-equal 0.99 (estimate-recovery-probability 0.80))
  (assert-equal 0.95 (estimate-recovery-probability 0.60))
  (assert-equal 0.5 (estimate-recovery-probability 0.30))
  (assert-equal 0.0 (estimate-recovery-probability 0.10)))

(deftest test-count-available-in-row
  (let ((matrix (make-array '(4 4) :initial-contents
                            '((1 nil 3 nil) (5 6 7 8) (nil nil nil nil) (13 14 15 16)))))
    (assert-equal 2 (count-available-in-row matrix 0))
    (assert-equal 4 (count-available-in-row matrix 1))
    (assert-equal 0 (count-available-in-row matrix 2))))

(deftest test-count-available-in-column
  (let ((matrix (make-array '(4 4) :initial-contents
                            '((1 nil 3 nil) (5 6 7 8) (nil nil nil nil) (13 14 15 16)))))
    (assert-equal 3 (count-available-in-column matrix 0))
    (assert-equal 2 (count-available-in-column matrix 1))))

;;; ============================================================================
;;; INTEGRATION TESTS
;;; ============================================================================

(deftest test-blob-to-extended-matrix
  (let* ((blob-data (make-array (list +das-rows+ +das-columns+) :initial-element 0))
         (blob-hash (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0))
         (matrix (blob-to-extended-matrix blob-data blob-hash)))
    (assert-true (extended-matrix-p matrix))
    (assert-equalp blob-hash (extended-matrix-blob-hash matrix))))

(deftest test-sample-data-availability
  (let* ((data (make-array (list +das-rows+ +das-columns+) :initial-element
                           (make-array +field-element-bytes+ :element-type '(unsigned-byte 8)
                                       :initial-element 0)))
         (matrix (encode-2d-erasure data))
         (blob-hash (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0)))
    (multiple-value-bind (available-p confidence verified failed)
        (sample-data-availability matrix blob-hash 0)
      (assert-true available-p)
      (assert-true (> confidence 0.95))
      (assert-true (> verified 0))
      (assert-equal 0 failed))))

;;; ============================================================================
;;; TEST RUNNER
;;; ============================================================================

(defun run-tests ()
  "Run all tests and report results."
  (setf *test-count* 0
        *pass-count* 0
        *fail-count* 0)

  (format t "~%Running cl-data-availability-sampling tests...~%~%")

  ;; Field tests
  (format t "Field Arithmetic:~%")
  (test-field-add)
  (test-field-mul)
  (test-field-exp)
  (test-mod-exp)

  ;; Byte manipulation tests
  (format t "~%Byte Manipulation:~%")
  (test-bytes-to-integer)
  (test-integer-to-bytes)
  (test-bytes-roundtrip)

  ;; SHA256 tests
  (format t "~%SHA256:~%")
  (test-sha256-produces-32-bytes)
  (test-sha256-deterministic)

  ;; Reed-Solomon tests
  (format t "~%Reed-Solomon:~%")
  (test-encode-2d-erasure-dimensions)
  (test-reed-solomon-encode-length)
  (test-extract-row)
  (test-extract-column)

  ;; Sampling tests
  (format t "~%Sampling:~%")
  (test-generate-sample-indices)
  (test-generate-sample-indices-deterministic)
  (test-compute-sampling-confidence)
  (test-required-samples-for-confidence)

  ;; DAS sample tests
  (format t "~%DAS Sample:~%")
  (test-make-das-sample)

  ;; Config tests
  (format t "~%Configuration:~%")
  (test-das-config-defaults)

  ;; Merkle tree tests
  (format t "~%Merkle Tree:~%")
  (test-compute-merkle-root-single)
  (test-compute-merkle-root-multiple)

  ;; Recovery tests
  (format t "~%Recovery:~%")
  (test-estimate-recovery-probability)
  (test-count-available-in-row)
  (test-count-available-in-column)

  ;; Integration tests
  (format t "~%Integration:~%")
  (test-blob-to-extended-matrix)
  (test-sample-data-availability)

  ;; Report
  (format t "~%========================================~%")
  (format t "Results: ~D tests, ~D passed, ~D failed~%"
          *test-count* *pass-count* *fail-count*)
  (format t "========================================~%")

  (zerop *fail-count*))
