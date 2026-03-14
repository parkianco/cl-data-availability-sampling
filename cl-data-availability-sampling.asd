;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: BSD-3-Clause

;;;; cl-data-availability-sampling.asd
;;;;
;;;; ASDF system definition for Data Availability Sampling library.

(asdf:defsystem #:cl-data-availability-sampling
  :description "Data Availability Sampling with 2D Reed-Solomon erasure codes"
  :author "Parkian Company LLC"
  :license "MIT"
  :version "0.1.0"
  :serial t
  :depends-on ()
  :components
  ((:file "package")
   (:module "src"
    :serial t
    :components
    ((:file "field")
     (:file "reed-solomon")
     (:file "sampling")
     (:file "das")
     (:file "util"))))
  :in-order-to ((asdf:test-op (test-op #:cl-data-availability-sampling/test))))

(asdf:defsystem #:cl-data-availability-sampling/test
  :description "Tests for cl-data-availability-sampling"
  :depends-on (#:cl-data-availability-sampling)
  :serial t
  :components
  ((:module "test"
    :components
    ((:file "test-das"))))
  :perform (asdf:test-op (o c)
             (let ((result (uiop:symbol-call :cl-data-availability-sampling/test :run-tests)))
               (unless result
                 (error "Tests failed")))))
