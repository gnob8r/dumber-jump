;;; dumb-jump.el --- Dumb jumping to declarations

;; Copyright (C) 2015 jack angers
;; Author: jack angers
;; Version: 1.0
;; Package-Requires: ((f "0.17.3") (s "1.9.0") (dash "2.9.0"))
;; Keywords: programming
;;; Commentary:

;; Uses `grep` to jump to the declaration for a variable/function under point via a set of regular expressions based on the file extension and language of the current buffer.

;;; Code:
(require 'org)
(require 'f)
(require 's)
(require 'dash)

;; TODO: config variable for if it should be only for functions
;; TODO: make defvars defcustoms?

;; TODO: add rules for more languages! (python and go)
;; TODO: make dumb-jump-test-rules run on boot?
;; TODO: prefix private functions with dj/ or simliar
;; TODO: time search operation. if above N then have a helpful not about setting up excludes

;;LANG=C grep -REn --exclude-dir /Users/jack/code/react-canvas/node_modules --exclude-dir /Users/jack/code/react-canvas/bower_components --include \*.js --include \*.jsx --include \*.html  -e '\s*width\s*=\s*' -e 'function\s*width\s*\(' -e '\s*width\s*=\s*function\s*\(' /Users/jack/code/react-canvas

;; https://github.com/jacktasia/dotemacs24/commit/3972d4decbb09f7dff78feb7cbc5db5b6979b0eb

(defvar dumb-jump-grep-prefix "LANG=C grep" "Prefix to grep command. Seemingly makes it faster for pure text.")

(defvar dumb-jump-grep-args "-REn" "Grep command args Recursive, [e]xtended regexes, and show line numbers")

(defvar dumb-jump-find-rules
  '((:type "function" :language "elisp"
           :regex "\\\(defun\\s+JJJ\\s*" :tests ("(defun test (blah)"))
    (:type "variable" :language "elisp"
           :regex "\\\(defvar\\b\\s*JJJ\\b\\s*" :tests ("(defvar test "))
    (:type "variable" :language "elisp"
           :regex "\\\(setq\\b\\s*JJJ\\b\\s*" :tests ("(setq test 123)"))
    ;; javascript
    (:type "variable" :language "javascript"
           :regex "\\s*JJJ\\s*=\\s*" :tests ("test = 1234"))

    ;; TODO: improve if argument dec is in the func sig
    ;; (:type "variable" :language "javascript"
    ;;        :regex "\\\(?\\s*JJJ\\s*,?\\s*\\\)?" :tests ("(test)" "(test, blah)" "(blah, test)"))
    (:type "function" :language "javascript"
           :regex "function\\s*JJJ\\s*\\\("
           :tests ("function test()" "function test ()"))
    (:type "function" :language "javascript"
           :regex "\\s*JJJ\\s*:\\s*function\\s*\\\("
           :tests ("test: function()"))
    (:type "function" :language "javascript"
           :regex "\\s*JJJ\\s*=\\s*function\\s*\\\("
           :tests ("test = function()")) )
  "List of regex patttern templates organized by language
and type to use for generating the grep command")

(defvar dumb-jump-language-file-exts
  '((:language "elisp" :ext "el")
    (:language "javascript" :ext "js")
    (:language "javascript" :ext "jsx")
    (:language "javascript" :ext "html"))
  "Mapping of programming lanaguage(s) to file extensions")

(defvar dumb-jump-language-contexts
  '((:language "javascript" :type "function" :right "(" :left nil)
    (:language "javascript" :type "variable" :right nil :left "(")
    (:language "javascript" :type "variable" :right ")" :left "(")
    (:language "javascript" :type "variable" :right "." :left nil)
    (:language "javascript" :type "variable" :right ";" :left nil)

    (:language "elisp" :type "variable" :right ")" :left " ")
    (:language "elisp" :type "function" :right " " :left "(")))

(defvar dumb-jump-project-denoters '(".dumbjump" ".projectile" ".git" ".hg" ".fslckout" ".bzr" "_darcs" ".svn" "Makefile")
  "Files and directories that signify a directory is a project root")

(defvar dumb-jump-default-project "~"
  "The default project to search for searching if a denoter is not found in parent of file")

(defun message-prin1 (str &rest args)
  (apply 'message str (-map 'prin1-to-string args)))

(defun dumb-jump-test-rules ()
  "Test all the rules and return count ofthose that fail
Optionally pass t to see a list of all failed rules"
  (let ((failures '())
        (fail-tmpl "FAILURE '%s' not in response '%s' | CMD: '%s' | rule: '%s'"))
    (-each dumb-jump-find-rules
      (lambda (rule)
        (-each (plist-get rule :tests)
          (lambda (test)
            (let* ((cmd (concat " echo '" test "' | grep -En -e '"  (s-replace "JJJ" "test" (plist-get rule :regex)) "'"))
                   (resp (shell-command-to-string cmd)))
              (when (not (s-contains? test resp))
                (add-to-list 'failures (format fail-tmpl test resp cmd rule))))
                ))))
    failures))

(defun dumb-jump-get-point-context (line func)
  (let* ((loc (s-index-of func line))
         (func-len (length func))
         (sen-len (length line))
         (right-loc-start (+ loc func-len))
         (right-loc-end (+ right-loc-start 1))
         (left (substring line (- loc 1) loc))
         (right (if (> right-loc-end sen-len)
                    ""
                  (substring line right-loc-start right-loc-end))))

       (org-combine-plists (plist-put nil :left left)
                           (plist-put nil :right right))))

(defun dumb-jump-generate-prompt-text (look-for proj results)
  (let* ((title (format "Multiple results for '%s':\n\n" look-for))
         (choices (-map-indexed (lambda (index result)
                                  (format "%d. %s:%s" (1+ index)
                                          (s-replace proj "" (plist-get result :path))
                                          (plist-get result :line)))
                                results)))
    (concat title (s-join "\n" choices) "\n\nChoice: ")))

(defun dumb-jump-parse-input (total input)
  (let* ((choice (string-to-number input)))
    (when (and
           (<= choice total)
           (>= choice 1))
      choice)))

(defun dumb-jump-prompt-user-for-choice (look-for proj results)
  (let* ((prompt-text (dumb-jump-generate-prompt-text look-for proj results))
         (input (read-from-minibuffer prompt-text))
         (choice (dumb-jump-parse-input (length results) input)))
    (if choice
      (dumb-jump-result-follow (nth (1- choice) results))
      (message "Sorry, that's an invalid choice."))))

;; this should almost always take (buffer-file-name)
(defun dumb-jump-get-project-root (filepath)
  "Keep looking at the parent dir of FILEPATH until a
denoter file/dir is found then return that directory
If not found, then return dumb-jump-default-profile"
  (let ((test-path filepath)
        (proj-file nil)
        (proj-root nil))
    (while (and (null proj-root)
                (not (null test-path)))
      (setq test-path (f-dirname test-path))
      (unless (null test-path)
        (-each dumb-jump-project-denoters
          (lambda (denoter)
            (when (f-exists? (f-join test-path denoter))
              (when (null proj-root)
                (setq proj-file denoter)
                (setq proj-root test-path)))))))
    (if (null proj-root)
      `(:root ,(f-long dumb-jump-default-project) :file nil)
      `(:root ,proj-root :file ,(f-join test-path proj-file)))))

(defun dumb-jump-get-language-by-filename (filename)
  "Get the programming language from the FILENAME"
  (let ((result (-filter
                 (lambda (f) (s-ends-with? (concat "." (plist-get f :ext)) filename))
                 dumb-jump-language-file-exts)))
    (if result
        (plist-get (car result) :language)
      nil)))

(defun dumb-jump-go ()
  "Go to the function/variable declaration for thing at point"
  (interactive)
  (let* ((cur-file (buffer-file-name))
         (cur-line (thing-at-point 'line))
         (cur-line-num (line-number-at-pos))
         (cur-symbol (thing-at-point 'symbol))
         (proj-info (dumb-jump-get-project-root cur-file))
         (proj-root (plist-get proj-info :root))
         (proj-config (plist-get proj-info :file))
         (look-for (thing-at-point 'symbol))
         (lang (dumb-jump-get-language-by-filename cur-file))
         (pt-ctx (dumb-jump-get-point-context cur-line cur-symbol))
         (ctx-type
          (dumb-jump-get-ctx-type-by-language lang pt-ctx))
         (regexes (dumb-jump-get-contextual-regexes lang ctx-type))
         (include-args (dumb-jump-get-ext-includes lang))
         (exclude-args (if (s-ends-with? "/.dumbjump" proj-config)
                           (dumb-jump-read-exclusions proj-config)
                           ""))
         (raw-results (dumb-jump-run-command look-for proj-root regexes include-args exclude-args cur-line-num))
         (results (-map (lambda (r) (plist-put r :target look-for)) raw-results))
         (result-count (length results))
         (top-result (car results)))
    ; (message-prin1 "lang:%s type:%s results: %s" lang ctx-type results)
    (cond
     ((and (not (listp results)) (s-blank? results))
      (message "Could not find rules for language '%s'." lang))
     ((= result-count 1)
      (dumb-jump-result-follow top-result))
     ((> result-count 1)
      ;; multiple results so let the user pick from a list
      ;; unless the match is in the current file
      (dumb-jump-handle-results results cur-file proj-root ctx-type look-for)
     )
     ((= result-count 0)
      (message "'%s' %s %s declaration not found." look-for (if (null lang) "" lang) (if (null ctx-type) "" ctx-type)))
     (t
      (message "Un-handled results: %s " (prin1-to-string results))))))

(defun dumb-jump-handle-results (results cur-file proj-root ctx-type look-for)
  (let* ((match-gt0 (-filter (lambda (x) (> (plist-get x :diff) 0)) results))
        (match-sorted (-sort (lambda (x y) (< (plist-get x :diff) (plist-get y :diff))) match-gt0))
        (matches (dumb-jump-current-file-results cur-file match-sorted))
        (var-to-jump (car matches))
        (do-var-jump (and (string= ctx-type "variable") var-to-jump)))
    ;(message-prin1 "type: %s | jump? %s | matches: %s | sorted: %s" ctx-type var-to-jump matches match-sorted)
    (if do-var-jump
        (dumb-jump-result-follow var-to-jump)
      (dumb-jump-prompt-user-for-choice look-for proj-root results))))

(defun dumb-jump-read-exclusions (config-file)
  (let* ((root (f-dirname config-file))
         (contents (f-read-text config-file))
         (lines (s-split "\n" contents))
         (exclude-lines (-filter (lambda (f) (s-starts-with? "-" f)) lines))
         (exclude-paths (-map (lambda (f)
                                 (let* ((dir (substring f 1))
                                       (use-dir (if (s-starts-with? "/" dir)
                                                    (substring dir 1)
                                                    dir)))
                                   (f-join root use-dir)))
                               exclude-lines)))
    (dumb-jump-arg-joiner "--exclude-dir" exclude-paths)))

(defun dumb-jump-result-follow (result)
  (let ((pos (s-index-of (plist-get result :target) (plist-get result :context))))
    (dumb-jump-goto-file-line (plist-get result :path) (plist-get result :line) pos)))

(defun dumb-jump-goto-file-line (thefile theline pos)
  "Open THEFILE and go line THELINE"
  ;(message "Going to file '%s' line %s" thefile theline)
  (find-file thefile)
  (goto-char (point-min))
  (forward-line (- theline 1))
  (forward-char pos))

(defun dumb-jump-current-file-results (path results)
  "Return the RESULTS that have the PATH"
  (let ((matched (-filter (lambda (r) (string= path (plist-get r :path))) results)))
    matched))

(defun dumb-jump-run-command (look-for proj regexes include-args exclude-args line-num)
  "Run the grep command based on the needle LOOKFOR in the directory TOSEARCH"
  (let* ((cmd (dumb-jump-generate-command look-for proj regexes include-args exclude-args))
         (rawresults (shell-command-to-string cmd)))
    ;(message "RUNNING CMD '%s'" cmd)
    (if (s-blank? cmd)
       nil
      (dumb-jump-parse-grep-response rawresults line-num))))

(defun dumb-jump-parse-grep-response (resp cur-line-num)
  "Takes a grep response RESP and parses into a list of plists"
  (let ((parsed (butlast (-map (lambda (line) (s-split ":" line)) (s-split "\n" resp)))))
    (-mapcat
      (lambda (x)
        (let* ((line-num (string-to-number (nth 1 x)))
              (diff (- cur-line-num line-num)))

        (list `(:path ,(nth 0 x) :line ,line-num :context ,(nth 2 x) :diff ,diff))))
        ;; (let ((item '()))
        ;;   (setq item (plist-put item :path (nth 0 x)))
        ;;   (setq item (plist-put item :line (nth 1 x)))
        ;;   (setq item (plist-put item :context (nth 2 x)))
        ;;   (list item)))
      parsed)))

(defun dumb-jump-get-ctx-type-by-language (lang pt-ctx)
  "Detect the type of context by the language"
  (let* ((contexts (-filter
                    (lambda (x) (string= (plist-get x ':language) lang))
                    dumb-jump-language-contexts))
         (usable-ctxs
          (if (> (length contexts) 0)
              (-filter (lambda (ctx)
                         (or (string= (plist-get ctx :left)
                                      (plist-get pt-ctx :left))
                             (string= (plist-get ctx :right)
                                      (plist-get pt-ctx :right))))
                       contexts)
            nil)))
    (when usable-ctxs
      (plist-get (car usable-ctxs) :type))))

(defun dumb-jump-get-ext-includes (language)
  (let ((exts (dumb-jump-get-file-exts-by-language language)))
    (dumb-jump-arg-joiner
     "--include"
     (-map
      (lambda (ext)
        (format "\\*.%s" ext))
      exts))))

(defun dumb-jump-arg-joiner (prefix values)
  (let ((args (s-join (format " %s " prefix) values)))
    (if args
      (format " %s %s " prefix args)
      "")))

(defun dumb-jump-get-contextual-regexes (lang ctx-type)
  (let* ((raw-rules
          (dumb-jump-get-rules-by-language lang))
         (ctx-rules
          (if ctx-type
              (-filter (lambda (r)
                         (string= (plist-get r :type)
                                   ctx-type))
                       raw-rules)
            raw-rules))
         (rules (if ctx-rules
                    ctx-rules
                  raw-rules))
         (regexes
          (-map
           (lambda (r)
             (format "'%s'" (plist-get r ':regex)))
           rules)))
    regexes))

(defun dumb-jump-generate-command (look-for proj regexes include-args exclude-args)
  "Generate the grep response based on the needle LOOK-FOR in the directory PROJ"
  (let* ((filled-regexes (-map (lambda (x) (s-replace "JJJ" look-for x))regexes))
         (regex-args (dumb-jump-arg-joiner "-e" filled-regexes)))
    (if (= (length regexes) 0)
        ""
        (concat dumb-jump-grep-prefix " " dumb-jump-grep-args exclude-args include-args regex-args  proj))))

(defun dumb-jump-get-file-exts-by-language (language)
  "Get list of file extensions for a language"
  (-map (lambda (x) (plist-get x :ext))
        (-filter (lambda (x) (string= (plist-get x :language) language)) dumb-jump-language-file-exts)))

(defun dumb-jump-get-rules-by-language (language)
  "Get list of rules for a language"
  (-filter (lambda (x) (string= (plist-get x ':language) language)) dumb-jump-find-rules))

(global-set-key (kbd "C-M-g") 'dumb-jump-go)

(provide 'dumb-jump)
;;; dumb-jump.el ends here
