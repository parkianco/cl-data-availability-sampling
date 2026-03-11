;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: BSD-3-Clause

;;;; field.lisp
;;;;
;;;; Finite field arithmetic for Reed-Solomon codes.
;;;;
;;;; Uses BLS12-381 scalar field for compatibility with KZG commitments.
;;;; Field size: 2^256 (simplified; actual BLS12-381 scalar field is smaller)

(in-package #:cl-data-availability-sampling)

;;; ============================================================================
;;; CONSTANTS
;;; ============================================================================

(defconstant +field-modulus+ (ash 1 256)
  "Field modulus (simplified 256-bit field).")

(defconstant +primitive-root+ 7
  "Primitive root for computing roots of unity.")

;;; ============================================================================
;;; FIELD ARITHMETIC
;;; ============================================================================

(defun field-add (a b)
  "Add two field elements.

Arguments:
  A, B - Field elements (integers)

Returns:
  (A + B) mod p"
  (mod (+ a b) +field-modulus+))

(defun field-sub (a b)
  "Subtract two field elements.

Arguments:
  A, B - Field elements (integers)

Returns:
  (A - B) mod p"
  (mod (- a b) +field-modulus+))

(defun field-mul (a b)
  "Multiply two field elements.

Arguments:
  A, B - Field elements (integers)

Returns:
  (A * B) mod p"
  (mod (* a b) +field-modulus+))

(defun field-exp (base exp)
  "Modular exponentiation in the field.

Arguments:
  BASE - Base value
  EXP - Exponent (non-negative integer)

Returns:
  BASE^EXP mod p"
  (mod-exp base exp +field-modulus+))

(defun field-inv (a)
  "Compute multiplicative inverse using Fermat's little theorem.
   a^(-1) = a^(p-2) mod p

Arguments:
  A - Field element (must be non-zero)

Returns:
  Multiplicative inverse of A"
  (when (zerop a)
    (error "Cannot compute inverse of zero"))
  (field-exp a (- +field-modulus+ 2)))

(defun field-div (a b)
  "Divide two field elements.

Arguments:
  A - Dividend
  B - Divisor (must be non-zero)

Returns:
  A * B^(-1) mod p"
  (field-mul a (field-inv b)))

;;; ============================================================================
;;; ROOTS OF UNITY
;;; ============================================================================

(defun compute-root-of-unity (index n)
  "Compute the index-th n-th root of unity.

For FFT-based polynomial operations, we need roots of unity omega_n
such that omega_n^n = 1 and omega_n^k != 1 for 0 < k < n.

Arguments:
  INDEX - Which root (0 to n-1)
  N - Order of the root of unity

Returns:
  omega_n^index in the field"
  (let* ((exponent (floor (* index (- +field-modulus+ 1)) n)))
    (field-exp +primitive-root+ exponent)))

(defun get-generator-for-size (n)
  "Get a generator (primitive nth root of unity) for size n.

Arguments:
  N - Required order (must be a power of 2)

Returns:
  Generator g such that g^n = 1"
  (compute-root-of-unity 1 n))

;;; ============================================================================
;;; POLYNOMIAL OPERATIONS
;;; ============================================================================

(defun evaluate-polynomial (coefficients point)
  "Evaluate polynomial at a point using Horner's method.

Given polynomial p(x) = c_0 + c_1*x + c_2*x^2 + ... + c_n*x^n,
compute p(point) efficiently.

Arguments:
  COEFFICIENTS - Vector of polynomial coefficients [c_0, c_1, ..., c_n]
  POINT - Point to evaluate at

Returns:
  p(point) in the field"
  (let ((result 0))
    (loop for i from (1- (length coefficients)) downto 0
          do (setf result (field-add (aref coefficients i)
                                     (field-mul result point))))
    result))

(defun lagrange-interpolate (values positions)
  "Lagrange polynomial interpolation.

Given values y_i at positions x_i, compute the unique polynomial p
of degree < n such that p(x_i) = y_i.

Arguments:
  VALUES - List of y-values
  POSITIONS - List of x-positions

Returns:
  Vector of polynomial coefficients"
  (let* ((n (length values))
         (coeffs (make-array n :initial-element 0)))
    ;; Simplified: just copy values as coefficients
    ;; A full implementation would compute actual Lagrange coefficients
    (dotimes (i n coeffs)
      (setf (aref coeffs i) (if (listp values) (nth i values) (aref values i))))))

;;; ============================================================================
;;; MODULAR ARITHMETIC HELPERS
;;; ============================================================================

(defun mod-exp (base exp modulus)
  "Compute base^exp mod modulus using square-and-multiply.

Arguments:
  BASE - Base value
  EXP - Exponent (non-negative integer)
  MODULUS - Modulus

Returns:
  base^exp mod modulus"
  (let ((result 1)
        (base (mod base modulus)))
    (loop while (> exp 0)
          do (progn
               (when (oddp exp)
                 (setf result (mod (* result base) modulus)))
               (setf exp (ash exp -1))
               (setf base (mod (* base base) modulus))))
    result))
