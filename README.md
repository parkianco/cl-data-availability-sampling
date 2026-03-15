# cl-data-availability-sampling

Pure Common Lisp implementation of Data Availability Sampling

## Overview
This library provides a robust, zero-dependency implementation of Data Availability Sampling for the Common Lisp ecosystem. It is designed to be highly portable, performant, and easy to integrate into any SBCL/CCL/ECL environment.

## Getting Started

Load the system using ASDF:

```lisp
(asdf:load-system #:cl-data-availability-sampling)
```

## Usage Example

```lisp
;; Initialize the environment
(let ((ctx (cl-data-availability-sampling:initialize-data-availability-sampling :initial-id 42)))
  ;; Perform batch processing using the built-in standard toolkit
  (multiple-value-bind (results errors)
      (cl-data-availability-sampling:data-availability-sampling-batch-process '(1 2 3) #'identity)
    (format t "Processed ~A items with ~A errors.~%" (length results) (length errors))))
```

## License
Apache-2.0
