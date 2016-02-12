;;; -*- lexical-binding: t -*-
(require 'f)
(require 's)
(require 'dash)
(require 'noflet)

(setq test-data-dir (f-expand "./test/data"))
(setq test-data-dir-elisp (f-join test-data-dir "proj2-elisp"))
(setq test-data-dir-proj1 (f-join test-data-dir "proj1"))

(ert-deftest data-dir-exists-test ()
  (should (f-dir? test-data-dir)))

(ert-deftest data-dir-proj2-exists-test ()
  (should (f-dir? test-data-dir-elisp)))

(ert-deftest dumb-jump-get-lang-by-ext-test ()
  (let ((lang1 (dumb-jump-get-language-by-filename "sldkfj.el"))
        (lang1b (dumb-jump-get-language-by-filename "sldkfj.el.gz"))
        (lang2 (dumb-jump-get-language-by-filename "/askdfjkl/somefile.js")))
    (should (string= lang1 "elisp"))
    (should (string= lang1b "elisp"))
    (should (string= lang2 "javascript"))))

(ert-deftest dumb-jump-current-files-results-test ()
  (let ((results '((:path "blah") (:path "rarr")))
        (expected '((:path "blah"))))
    (should (equal (dumb-jump-current-file-results "blah" results) expected))))

(ert-deftest dumb-jump-exclude-path-test ()
  (let* ((expected (list (f-join test-data-dir-proj1 "ignored")))
         (root (dumb-jump-get-project-root test-data-dir-proj1))
         (excludes (dumb-jump-read-exclusions test-data-dir-proj1  ".dumbjump")))
    (should (equal excludes expected))))

(ert-deftest dumb-jump-exclude-path-blank-test ()
  (let* ((excludes (dumb-jump-read-exclusions test-data-dir-proj1 ".dumbjump-blank")))
    (should (null excludes))))

(ert-deftest dumb-jump-language-to-ext-test ()
  (should (-contains? (dumb-jump-get-file-exts-by-language "elisp") "el")))

(ert-deftest dumb-jump-generate-cmd-include-args ()
  (let ((args (dumb-jump-get-ext-includes "javascript"))
        (expected " --include \\*.js --include \\*.jsx --include \\*.html "))
    (should (string= expected args))))

(ert-deftest dumb-jump-generate-grep-command-no-ctx-test ()
  (let ((regexes (dumb-jump-get-contextual-regexes "elisp" nil))
        (expected "LANG=C grep -REn --include \\*.el --include \\*.el.gz -e '\\(defun\\s+tester\\b\\s*' -e '\\(defvar\\b\\s*tester\\b\\s?' -e '\\(defcustom\\b\\s*tester\\b\\s?' -e '\\(setq\\b\\s*tester\\b\\s*' -e '\\(tester\\s+' -e '\\(defun\\s*.+\\(?\\s*tester\\b\\s*\\)?' ."))
    (should (string= expected  (dumb-jump-generate-grep-command  "tester" "blah.el" "." regexes "elisp" nil)))))

(ert-deftest dumb-jump-generate-ag-command-no-ctx-test ()
  (let ((regexes (dumb-jump-get-contextual-regexes "elisp" nil))
        (expected "ag --nocolor --nogroup '\\(defun\\s+tester\\b\\s*|\\(defvar\\b\\s*tester\\b\\s?|\\(defcustom\\b\\s*tester\\b\\s?|\\(setq\\b\\s*tester\\b\\s*|\\(tester\\s+|\\(defun\\s*.+\\(?\\s*tester\\b\\s*\\)?' ."))
    (should (string= expected  (dumb-jump-generate-ag-command  "tester" "blah.el" "." regexes "elisp" nil)))))


(ert-deftest dumb-jump-generate-grep-command-no-ctx-funcs-only-test ()
  (let* ((dumb-jump-functions-only t)
        (regexes (dumb-jump-get-contextual-regexes "elisp" nil))
        (expected "LANG=C grep -REn -e '\\(defun\\s+tester\\b\\s*' .")
        (zexpected "LANG=C zgrep -REn -e '\\(defun\\s+tester\\b\\s*' ."))
    (should (string= expected  (dumb-jump-generate-grep-command  "tester" "blah.el" "." regexes "" nil)))
    (should (string= zexpected  (dumb-jump-generate-grep-command  "tester" "blah.el.gz" "." regexes "" nil)))))

(ert-deftest dumb-jump-generate-grep-command-with-ctx-test ()
  (let* ((ctx-type (dumb-jump-get-ctx-type-by-language "elisp" '(:left "(" :right nil)))
         (dumb-jump-ignore-context nil) ;; overriding the default
         (regexes (dumb-jump-get-contextual-regexes "elisp" ctx-type))
         (expected "LANG=C grep -REn -e '\\(defun\\s+tester\\b\\s*' ."))
    ;; the point context being passed should match a "function" type so only the one command
    (should (string= expected  (dumb-jump-generate-grep-command "tester" "blah.el" "." regexes "" nil)))))

(ert-deftest dumb-jump-generate-grep-command-with-ctx-but-ignored-test ()
  (let* ((ctx-type (dumb-jump-get-ctx-type-by-language "elisp" '(:left "(" :right nil)))
         (dumb-jump-ignore-context t)
         (regexes (dumb-jump-get-contextual-regexes "elisp" ctx-type))
         (expected "LANG=C grep -REn -e '\\(defun\\s+tester\\b\\s*' -e '\\(defvar\\b\\s*tester\\b\\s?' -e '\\(defcustom\\b\\s*tester\\b\\s?' -e '\\(setq\\b\\s*tester\\b\\s*' -e '\\(tester\\s+' -e '\\(defun\\s*.+\\(?\\s*tester\\b\\s*\\)?' ."))

    ;; the point context being passed is ignored so ALL should return
    (should (string= expected  (dumb-jump-generate-grep-command "tester" "blah.el" "." regexes "" nil)))))

(ert-deftest dumb-jump-generate-bad-grep-command-test ()
    (should (s-blank? (dumb-jump-generate-grep-command "tester" "blah.el" "." nil "" (list "skaldjf")))))

(ert-deftest dumb-jump-generate-bad-ag-command-test ()
    (should (s-blank? (dumb-jump-generate-ag-command "tester" "blah.el" "." nil "" (list "skaldjf")))))

(ert-deftest dumb-jump-grep-parse-test ()
  (let* ((resp "./dumb-jump.el:22:(defun dumb-jump-asdf ()\n./dumb-jump.el:26:(defvar dumb-jump-grep-prefix )\n./dumb-jump2.el:28:(defvar dumb-jump-grep)")
         (parsed (dumb-jump-parse-grep-response resp "dumb-jump2.el" 28))
         (test-result (nth 1 parsed)))
    (should (= (plist-get test-result :diff) 2))
    (should (= (plist-get test-result :diff) 2))
    (should (= (plist-get test-result ':line) 26))))

(ert-deftest dumb-jump-ag-parse-test ()
  (let* ((resp "./dumb-jump.el:22:1:(defun dumb-jump-asdf ()\n./dumb-jump.el:26:1:(defvar dumb-jump-grep-prefix )\n./dumb-jump2.el:28:1:(defvar dumb-jump-grep)")
         (parsed (dumb-jump-parse-ag-response resp "dumb-jump2.el" 28))
         (test-result (nth 1 parsed)))
    (should (= (plist-get test-result :diff) 2))
    (should (= (plist-get test-result :diff) 2))
    (should (= (plist-get test-result ':line) 26))))

(ert-deftest dumb-jump-run-cmd-test ()
  (let* ((regexes (dumb-jump-get-contextual-regexes "elisp" nil))
         (results (dumb-jump-run-command "another-fake-function" test-data-dir-elisp regexes "" ""  "blah.el" 3))
        (first-result (car results)))
    (should (s-contains? "/fake.el" (plist-get first-result :path)))
    (should (= (plist-get first-result :line) 6))))

(ert-deftest dumb-jump-run-grep-cmd-test ()
  (let* ((dumb-jump-force-grep t)
         (regexes (dumb-jump-get-contextual-regexes "elisp" nil))
         (results (dumb-jump-run-command "another-fake-function" test-data-dir-elisp regexes "" ""  "blah.el" 3))
        (first-result (car results)))
    (should (s-contains? "/fake.el" (plist-get first-result :path)))
    (should (= (plist-get first-result :line) 6))))

(ert-deftest dumb-jump-run-cmd-fail-test ()
  (let* ((results (dumb-jump-run-command "hidden-function" test-data-dir-elisp nil "" "" "blah.el" 3))
        (first-result (car results)))
    (should (null first-result))))

(ert-deftest dumb-jump-find-proj-root-test ()
  (let* ((js-file (f-join test-data-dir-proj1 "src" "js"))
         (found-project (dumb-jump-get-project-root js-file)))
    (should (f-exists? found-project))
    (should (string= found-project test-data-dir-proj1))
    (should (string= ".dumbjump" (dumb-jump-get-config found-project)))))

(ert-deftest dumb-jump-goto-file-line-test ()
  (let ((js-file (f-join test-data-dir-proj1 "src" "js" "fake.js")))
    (dumb-jump-goto-file-line js-file 3 0)
    (should (string= (buffer-file-name) js-file))
    (should (= (line-number-at-pos) 3))))


(ert-deftest dumb-jump-goto-file-point-test ()
  (let ((js-file (f-join test-data-dir-proj1 "src" "js" "fake.js")))
    (dumb-jump-goto-file-point js-file 10)
    (should (string= (buffer-file-name) js-file))
    (should (= (point) 10))))

(ert-deftest dumb-jump-test-rules-test ()
  (let ((rule-failures (dumb-jump-test-rules)))
    (should (= (length rule-failures) 0))))

(ert-deftest dumb-jump-test-rules-fail-test ()
  (let* ((bad-rule '(:type "variable" :language "elisp" :regex "\\\(defvarJJJ\\b\\s*" :tests ("(defvar test ")))
         (dumb-jump-find-rules (cons bad-rule dumb-jump-find-rules))
         (rule-failures (dumb-jump-test-rules)))
    ;(message "%s" (prin1-to-string rule-failures))
    (should (= (length rule-failures) 1))))

(ert-deftest dumb-jump-match-test ()
  (should (not (dumb-jump-re-match nil "asdf")))
  (should (dumb-jump-re-match "^asdf$" "asdf"))
  (should (string= (car (dumb-jump-re-match "^[0-9]+$" "123")) "123")))

(ert-deftest dumb-jump-context-point-test ()
  (let* ((sentence "mainWindow.loadUrl('file://')")
         (func "loadUrl")
         (ctx (dumb-jump-get-point-context sentence func 15)))
         (should (string= (plist-get ctx :left) "mainWindow."))
         (should (string= (plist-get ctx :right) "('file://')"))))

(ert-deftest dumb-jump-context-point-type-test ()
  (let* ((sentence "mainWindow.loadUrl('file://' + __dirname + '/dt/inspector.html?electron=true');")
         (func "loadUrl")
         (pt-ctx (dumb-jump-get-point-context sentence func 14))
         (ctx-type (dumb-jump-get-ctx-type-by-language "javascript" pt-ctx)))
    (should (string= ctx-type "function"))))

(ert-deftest dumb-jump-multiple-choice-input-test ()
  (progn
    (should (= (dumb-jump-parse-input 5 "4") 4))
    (should (= (dumb-jump-parse-input 50 "1") 1))
    (should (null (dumb-jump-parse-input 50 "242")))
    (should (null (dumb-jump-parse-input 5 "0")))
    (should (null (dumb-jump-parse-input 500 "asdf")))
    (should (null (dumb-jump-parse-input 5 "6")))))

(ert-deftest dumb-jump-multiple-choice-text-test ()
  (let* ((choice-txt (dumb-jump-generate-prompt-text "asdf" "/usr/blah" '((:path "/usr/blah/test.txt" :line "54"))))
         (expected "Multiple results for 'asdf':\n\n1. /test.txt:54\n\nChoice: "))
    (should (string= choice-txt expected))))

(ert-deftest dumb-jump-prompt-user-for-choice-invalid-test ()
  (noflet ((read-from-minibuffer (input) "2")
           (dumb-jump-message (input)
             (should (string= input "Sorry, that's an invalid choice."))))

    (dumb-jump-prompt-user-for-choice "asdf" "/usr/blah" '((:path "/usr/blah/test.txt" :line "54")))))

(ert-deftest dumb-jump-prompt-user-for-choice-correct-test ()
  (noflet ((read-from-minibuffer (input) "2")
           (dumb-jump-result-follow (result)
                                    (should (string= (plist-get result :path) "/usr/blah/test2.txt"))))

    (dumb-jump-prompt-user-for-choice "asdf" "/usr/blah" '((:path "/usr/blah/test.txt" :line "54") (:path "/usr/blah/test2.txt" :line "52")))))

(ert-deftest dumb-jump-fetch-results-test ()
  (let ((js-file (f-join test-data-dir-proj1 "src" "js" "fake.js")))
    (with-current-buffer (find-file-noselect js-file t)
      (goto-char (point-min))
      (forward-line 2)
      (forward-char 10)
      (let ((results (dumb-jump-fetch-results)))
        (should (string= "doSomeStuff" (plist-get results :symbol)))
        (should (string= "javascript" (plist-get results :lang)))))))

(ert-deftest dumb-jump-go-test ()
  (let ((js-file (f-join test-data-dir-proj1 "src" "js" "fake2.js"))
        (go-js-file (f-join test-data-dir-proj1 "src" "js" "fake.js")))
    (with-current-buffer (find-file-noselect js-file t)
      (goto-char (point-min))
      (forward-char 13)
      (noflet ((dumb-jump-result-follow (result)
                                        (should (string= (plist-get result :path) go-js-file))))
        (dumb-jump-go)))))

(ert-deftest dumb-jump-go-var-let-test ()
  (let ((el-file (f-join test-data-dir-elisp "fake2.el")))
    (with-current-buffer (find-file-noselect el-file t)
      (goto-char (point-min))
      (forward-line 13)
      (forward-char 33)
      (noflet ((dumb-jump-handle-results (a b c d e)
                                         (should (= (length a) 3))
                                         (funcall this-fn a b c d e))
               (dumb-jump-result-follow (result)
                                        (should (string= (plist-get result :path) el-file))
                                        (should (= (plist-get result :line) 11))))
        (dumb-jump-go)))))

(ert-deftest dumb-jump-go-var-let-repeat-test ()
  (let ((el-file (f-join test-data-dir-elisp "fake2.el")))
    (with-current-buffer (find-file-noselect el-file t)
      (goto-char (point-min))
      (forward-line 21)
      (forward-char 33)
      (noflet ((dumb-jump-handle-results (a b c d e)
                                         (should (= (length a) 3))
                                         (funcall this-fn a b c d e))
               (dumb-jump-result-follow (result)
                                        (should (string= (plist-get result :path) el-file))
                                        (should (= (plist-get result :line) 18))))
        (dumb-jump-go)))))

(ert-deftest dumb-jump-go-var-arg-test ()
  (let ((el-file (f-join test-data-dir-elisp "fake2.el")))
    (with-current-buffer (find-file-noselect el-file t)
      (goto-char (point-min))
      (forward-line 4)
      (forward-char 12)
      (noflet ((dumb-jump-handle-results (a b c d e)
                                         (should (= (length a) 3))
                                         (funcall this-fn a b c d e))
               (dumb-jump-result-follow (result)
                                        (should (string= (plist-get result :path) el-file))
                                        (should (= (plist-get result :line) 3))))
        (dumb-jump-go)))))

(ert-deftest dumb-jump-back-test ()
  (let ((js-file (f-join test-data-dir-proj1 "src" "js" "fake2.js"))
        (go-js-file (f-join test-data-dir-proj1 "src" "js" "fake.js")))
    (with-current-buffer (find-file-noselect js-file t)
      (goto-char (point-min))
      (forward-char 13)
      (noflet ((dumb-jump-goto-file-point (path point)
                                          (should (= point 14)))
               (dumb-jump-message (input arg1 arg2)))
        (dumb-jump-go)
        (dumb-jump-back)))))

(ert-deftest dumb-jump-go-no-result-test ()
  (let ((js-file (f-join test-data-dir-proj1 "src" "js" "fake2.js")))
    (with-current-buffer (find-file-noselect js-file t)
      (goto-char (point-min))
      (noflet ((dumb-jump-message (input arg1 arg2 arg3)
               (should (string= input "'%s' %s %s declaration not found."))
               (should (string= arg1 "console"))))
        (dumb-jump-go)))))

(ert-deftest dumb-jump-go-no-rules-test ()
  (let ((txt-file (f-join test-data-dir-proj1 "src" "js" "nocode.txt")))
    (with-current-buffer (find-file-noselect txt-file t)
      (goto-char (point-min))
      (noflet ((dumb-jump-message (input arg1)
               (should (string= input "Could not find rules for '%s'."))
               (should (string= arg1 ".txt file"))))
        (dumb-jump-go)))))

(ert-deftest dumb-jump-go-too-long-test ()
  (let ((txt-file (f-join test-data-dir-proj1 "src" "js" "nocode.txt"))
        (dumb-jump-max-find-time 0.2))
    (with-current-buffer (find-file-noselect txt-file t)
      (goto-char (point-min))
      (noflet ((dumb-jump-fetch-results ()
                                        (sleep-for 0 300)
                                        '())
               (dumb-jump-message (input arg1 arg2 arg3)
                        (should (= (string-to-number arg1) dumb-jump-max-find-time))
                        (should (string= input "Took over %ss to find '%s'. Please install ag or add a .dumbjump file to '%s' with path exclusions"))))

               (dumb-jump-go)))))

(ert-deftest dumb-jump-message-handle-results-test ()
  (noflet ((dumb-jump-result-follow (result)
                                    (should (= (plist-get result :line) 62))))
          (let ((results '((:path "src/file.js" :line 62 :context "var isNow = true" :diff 7 :target "isNow")
                           (:path "src/file.js" :line 69 :context "isNow = false" :diff 0 :target "isNow"))))
                (dumb-jump-handle-results results "src/file.js" "/code/redux" "" "isNow"))))

(ert-deftest dumb-jump-message-result-follow-test ()
  (noflet ((dumb-jump-goto-file-line (path line pos)
                                     (should (string= path "src/file.js"))
                                     (should (= line 62))
                                     (should (= pos 4))))
          (let ((result '(:path "src/file.js" :line 62 :context "var isNow = true" :diff 7 :target "isNow")))
            (dumb-jump-result-follow result))))

(ert-deftest dumb-jump-populate-regexes-test ()
  (should (equal (dumb-jump-populate-regexes "testvar" '("JJJ\\s*=\\s*")) '("testvar\\s*=\\s*")))
  (should (equal (dumb-jump-populate-regexes "$testvar" '("JJJ\\s*=\\s*")) '("\\$testvar\\s*=\\s*"))))

(ert-deftest dumb-jump-message-prin1-test ()
  (noflet ((message (input arg arg2)
                    (should (string= input "%s %s"))
                    (should (string= arg "(:path \"test\" :line 24)"))
                    (should (string= arg2 "3"))))
          (dumb-jump-message-prin1 "%s %s" '(:path "test" :line 24) 3)))

(ert-deftest dumb-jump-message-test ()
  (noflet ((message (input arg arg2)
                    (should (string= input "%s %s"))
                    (should (string= arg "two"))
                    (should (string= arg2 "three"))))
          (dumb-jump-message "%s %s" "two" "three")))

(ert-deftest dumb-jump-concat-command-test ()
  (should (string= (dumb-jump-concat-command " test1 " "test2 " "   test3")
                   "test1 test2 test3")))

(ert-deftest dumb-jump-find-start-pos-test ()
  (let ((cur-pos 9)
        (line "event event")
        (word "event"))
    (should (= (dumb-jump-find-start-pos line word cur-pos) 6))))
