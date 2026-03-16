;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(defpackage #:cl-data-availability-sampling.test
  (:use #:cl #:cl-data-availability-sampling)
  (:export #:run-tests))

(in-package #:cl-data-availability-sampling.test)

(defun run-tests ()
  (format t "Running professional test suite for cl-data-availability-sampling...~%")
  (assert (initialize-data-availability-sampling))
  (format t "Tests passed!~%")
  t)
