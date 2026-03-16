(asdf:defsystem #:cl-data-availability-sampling
  :depends-on (#:alexandria #:bordeaux-threads)
  :components ((:module "src"
                :components ((:file "package")
                             (:file "cl-data-availability-sampling" :depends-on ("package"))))))