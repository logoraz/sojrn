(uiop:define-package :sojrn/lib/syntax
  (:use :cl)
  (:export #:concat
           #:join-strings
           #:nlet)
  (:documentation "Syntactic Language Extensions."))
(in-package :sojrn/lib/syntax)


;;; String Manipulation

(defun concat (&rest strings)
  "Shorthand for CONCATENATE specialized for strings."
  (apply #'concatenate 'string strings))

(defun join-strings (strings &key (separator ""))
  "Join STRINGS into one string, placing SEPARATOR between adjacent elements.
Return \"\" if STRINGS is empty."
  (with-output-to-string (out)
    (loop :for (string . more) :on strings
          :do (write-string string out)
              (when more (write-string separator out)))))


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
