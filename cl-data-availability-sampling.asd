;;;; cl-data-availability-sampling.asd
;;;;
;;;; ASDF system definition for Data Availability Sampling library.

(asdf:defsystem #:cl-data-availability-sampling
  :description "Data Availability Sampling with 2D Reed-Solomon erasure codes"
  :author "CLPIC Project"
  :license "MIT"
  :version "1.0.0"
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
  :in-order-to ((test-op (test-op #:cl-data-availability-sampling/test))))

(asdf:defsystem #:cl-data-availability-sampling/test
  :description "Tests for cl-data-availability-sampling"
  :depends-on (#:cl-data-availability-sampling)
  :serial t
  :components
  ((:module "test"
    :components
    ((:file "test-das"))))
  :perform (test-op (o c)
             (uiop:symbol-call :cl-data-availability-sampling/test :run-tests)))
