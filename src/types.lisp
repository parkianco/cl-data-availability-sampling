;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-data-availability-sampling)

;;; Core types for cl-data-availability-sampling
(deftype cl-data-availability-sampling-id () '(unsigned-byte 64))
(deftype cl-data-availability-sampling-status () '(member :ready :active :error :shutdown))
