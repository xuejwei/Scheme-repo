(module drracket-init mzscheme  
  (require (lib "pretty.ss"))  
  (require (lib "trace.ss"))
  (provide (all-from (lib "pretty.ss")))
  (provide (all-from (lib "trace.ss")))
  
  (provide make-parameter
           ; 
           run-experiment
           run-tests!
           ; setting options
           stop-after-first-error
           run-quietly
           )

  ; makes structs printable,
  ; provides basic functionality for testing.  This includes pretty-printing and tracing.
  ; ============================================================================
  
  ; show the contents of define-datatype values
  (print-struct #t)
  
  ; safely apply procedure fn to a list of args.
  ;   1. if successful, return (cons #t val)
  ;   2. if eopl:error is invoked, returns (cons #f string), where string is the format string generated by eopl:error.  
  ;   3. If somebody manages to raise a value other than an exception, then the raised value is reported. 
  (define apply-safely
    (lambda (proc args)
      (with-handlers ([(lambda (exn) #t)      ; catch any error
                       (lambda (exn)          ; evaluate to a failed test result
                         (cons #f 
                               (if (exn? exn)
                                   (exn-message exn)
                                   exn)))])  
        (let ([actual (apply proc args)])
          (cons #t actual)))))

  ; run-experiment :: (Args -> b) -> Args -> b -> (b -> b -> bool) -> (cons bool b)  
  ; usage: (run-experiment fn args correct-answer equal-answer?)
  
  ; Applies fn to args.
  ; Compares the result to correct-answer. 
  ; Returns (cons bool b) where bool indicates whether the answer is correct.
  (define run-experiment
    (lambda (fn args correct-answer equal-answer?)
      (let* [(result (apply-safely fn args))             
             (error-thrown? (not (car result)))
             (ans (cdr result))] ; ans is either the answer or the args to eopl:error          
        (cons (if (eqv? correct-answer 'error)
                  error-thrown?
                  (equal-answer? ans correct-answer))
              ans))))

  ; make-parameter : 专门用于"setting options"
  ;    (define setting (make-parameter #f)
  ;    ====>  if (setting)  得到 #f
  ;    ====>  (setting #t) ; if (setting) 得到 #t
  (define stop-after-first-error (make-parameter #f))
  (define run-quietly (make-parameter #t))
   
  ; run-tests! : (arg -> outcome) * (any * any -> bool) * (list-of test) -> unspecified
  ; usage: (run-tests! run-fn equal-answer? tests)

  ; where:
  ; test ::= (name arg outcome)
  ; outcome ::= ERROR | any

  ; for each item in tests, apply run-fn to the arg. 
  ; Check to see ifthe outcome is right, comparing values using equal-answer?.
  ; print a log of the tests.
  ; at the end, print either "no bugs found" or the list of tests failed. 
  
  ; Normally, run-tests! will recover from any error and continue to the end of the test suite. 
  ; This behavior can be altered by setting (stop-after-first-error #t).

  (define (run-tests! run-fn equal-answer? tests)
    (let ((failed-tests '()))
      (for-each
       (lambda (test-item)
         (let [(name (car test-item))
               (pgm (cadr test-item))
               (correct-answer (caddr test-item))]
           (printf "test: ~a~%" name)
           
           (let* [(result (run-experiment run-fn (list pgm) correct-answer equal-answer?))
                  (correct? (car result))
                  (actual-answer (cdr result))]
             (if (or (not correct?) (not (run-quietly)))
                 (begin
                   (printf "~a~%" pgm)
                   (printf "correct outcome: ~a~%" correct-answer)
                   (printf "actual outcome:  ")
                   (pretty-display actual-answer)))
             (if correct?
                 (printf "correct~%~%")
                 (begin
                   (printf "incorrect~%~%")
                   ; stop on first error if stop-after-first? is set:
                   (if (stop-after-first-error) (error name "incorrect outcome detected"))                        
                   (set! failed-tests (cons name failed-tests)))))))
       tests)
      (if (null? failed-tests)
          (printf "no bugs found~%")
          (printf "incorrect answers on tests: ~a~%"
                  (reverse failed-tests)))))

  )  
  
  
