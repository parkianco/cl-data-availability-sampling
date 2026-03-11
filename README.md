# cl-data-availability-sampling

Data Availability Sampling with 2D Reed-Solomon erasure codes with **zero external dependencies**.

## Features

- **2D Reed-Solomon**: Row and column erasure coding
- **Random sampling**: Probabilistic data availability verification
- **KZG commitments**: Polynomial commitment proofs (optional)
- **Danksharding ready**: EIP-4844 blob transaction support
- **Pure Common Lisp**: No CFFI, no external libraries

## Installation

```lisp
(asdf:load-system :cl-data-availability-sampling)
```

## Quick Start

```lisp
(use-package :cl-data-availability-sampling)

;; Encode data for sampling
(let* ((data (random-bytes 4096))
       (encoded (das-encode data :rows 64 :cols 64)))
  ;; Get samples for verification
  (let ((samples (das-sample encoded :count 75)))
    ;; Verify availability
    (das-verify samples)))
```

## API Reference

### Encoding

- `(das-encode data &key rows cols)` - Encode data with 2D RS
- `(das-decode samples &key rows cols)` - Decode from samples
- `(das-extend-row row)` - Extend row with parity
- `(das-extend-col col)` - Extend column with parity

### Sampling

- `(das-sample encoded &key count)` - Random sample cells
- `(das-verify samples)` - Verify samples are consistent
- `(das-proof cell-x cell-y)` - Generate proof for cell

## Testing

```lisp
(asdf:test-system :cl-data-availability-sampling)
```

## License

BSD-3-Clause

Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
