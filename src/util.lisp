;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: BSD-3-Clause

;;;; util.lisp
;;;;
;;;; Utility functions for Data Availability Sampling.
;;;;
;;;; Provides cryptographic primitives and byte manipulation helpers.

(in-package #:cl-data-availability-sampling)

;;; ============================================================================
;;; CRYPTOGRAPHIC HASHING
;;; ============================================================================

(defun sha256 (data)
  "Compute SHA-256 hash of data.

This is a simplified implementation for demonstration.
Production code should use a proper SHA-256 implementation.

Arguments:
  DATA - Byte vector to hash

Returns:
  32-byte hash result"
  (let* ((hash (make-array 32 :element-type '(unsigned-byte 8)))
         (data-vec (if (vectorp data) data (coerce data 'vector))))
    ;; Simplified hash using sxhash and bit manipulation
    ;; In production, use a real SHA-256 implementation
    (let ((h (sxhash data-vec)))
      (dotimes (i 32 hash)
        (setf (aref hash i)
              (logand #xff (ash h (- (* i 8)))))))))

;;; ============================================================================
;;; BYTE MANIPULATION
;;; ============================================================================

(defun bytes-to-integer (bytes)
  "Convert byte vector to integer (big-endian).

Arguments:
  BYTES - Byte vector

Returns:
  Integer value"
  (let ((result 0))
    (loop for byte across bytes
          do (setf result (+ (ash result 8) byte)))
    result))

(defun integer-to-bytes (integer size)
  "Convert integer to byte vector (big-endian).

Arguments:
  INTEGER - Integer value
  SIZE - Number of bytes to produce

Returns:
  Byte vector of specified size"
  (let ((result (make-array size :element-type '(unsigned-byte 8))))
    (loop for i from (1- size) downto 0
          do (setf (aref result (- (1- size) i))
                   (ldb (byte 8 (* i 8)) integer)))
    result))

;;; ============================================================================
;;; MERKLE TREE
;;; ============================================================================

(defun compute-merkle-root (leaves)
  "Compute Merkle root of leaves.

Arguments:
  LEAVES - List of 32-byte leaf hashes

Returns:
  32-byte root hash"
  (cond
    ((null leaves)
     (make-array 32 :element-type '(unsigned-byte 8) :initial-element 0))
    ((= (length leaves) 1)
     (first leaves))
    (t
     (compute-merkle-root
      (loop for (a b) on leaves by #'cddr
            collect (sha256 (concatenate '(vector (unsigned-byte 8))
                                         a (or b a))))))))

(defun verify-merkle-proof (leaf-hash proof root-hash index)
  "Verify a Merkle proof.

Arguments:
  LEAF-HASH - Hash of the leaf being proven
  PROOF - List of sibling hashes from leaf to root
  ROOT-HASH - Expected root hash
  INDEX - Leaf index

Returns:
  T if proof is valid"
  (let ((current leaf-hash)
        (idx index))
    (dolist (sibling proof)
      (setf current
            (if (evenp idx)
                (sha256 (concatenate '(vector (unsigned-byte 8)) current sibling))
                (sha256 (concatenate '(vector (unsigned-byte 8)) sibling current))))
      (setf idx (floor idx 2)))
    (equalp current root-hash)))

;;; ============================================================================
;;; BLOB HASH
;;; ============================================================================

(defun compute-blob-hash (blob-data)
  "Compute hash of blob data for identification.

Arguments:
  BLOB-DATA - Raw blob bytes

Returns:
  32-byte blob hash"
  (sha256 blob-data))

;;; ============================================================================
;;; RANDOM NUMBER GENERATION
;;; ============================================================================

(defun generate-random-bytes (n)
  "Generate n random bytes.

Arguments:
  N - Number of bytes

Returns:
  Byte vector of random values"
  (let ((result (make-array n :element-type '(unsigned-byte 8))))
    (dotimes (i n result)
      (setf (aref result i) (random 256)))))

(defun generate-random-field-element ()
  "Generate a random field element.

Returns:
  Random integer in field"
  (random +field-modulus+))
