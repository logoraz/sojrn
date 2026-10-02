(uiop:define-package :sojrn/lib/syntax
  (:use :cl)
  (:export #:concat
           #:nlet)
  (:documentation "Syntactic Language Extensions."))

(in-package :sojrn/lib/syntax)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; String Manipulation

(defun concat (&rest strings)
  "Shorthand for CONCATENATE specialized for strings."
  (apply #'concatenate 'string strings))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Macros

(defmacro nlet (name bindings &body body)
  `(labels ((,name ,(mapcar #'car bindings) ,@body))
     (,name ,@(mapcar #'cadr bindings))))

#+(or) ;example
(nlet fact ((n 5) (acc 1))
      (if (zerop n)
          acc
          (fact (1- n) (* acc n))))  ; => 120

#+(or) ;Equivalent to "named let" factorial
(labels ((fact (n acc)
           (if (zerop n)
               acc
               (fact (1- n) (* acc n)))))
  (fact 5 1))  ; => 120

