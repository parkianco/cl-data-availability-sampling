;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-data-availability-sampling)

(define-condition cl-data-availability-sampling-error (error)
  ((message :initarg :message :reader cl-data-availability-sampling-error-message))
  (:report (lambda (condition stream)
             (format stream "cl-data-availability-sampling error: ~A" (cl-data-availability-sampling-error-message condition)))))
