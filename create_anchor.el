;;https://emacs.stackexchange.com/questions/22079/how-to-write-assertions
(defmacro assert (test-form)
  `(when (not ,test-form)
     (error "Assertion failed: %s" (format "%s" ',test-form)))) 

(defun my-po-get-previous-msgid (kill-flag)
  (let ((buffer (current-buffer))
        (obsolete (eq po-entry-type 'obsolete)))
    (save-excursion
      (goto-char po-start-of-entry)
      (if (re-search-forward
	   po-any-previous-msgid-regexp
	   po-end-of-entry t)
          (po-with-temp-buffer
            (insert-buffer-substring buffer (match-beginning 0) (match-end 0))
            (goto-char (point-min))
            (while (not (eobp))
              (if (looking-at (if obsolete "#|\\(\n\\| \\)" "#| ?"))
                  (replace-match "" t t))
              (forward-line 1))
            (and kill-flag (copy-region-as-kill (point-min) (point-max)))
            (po-extract-unquoted (current-buffer)
                                     (point-min)
                                     (point-max)))
        ""))))

;;(setq my-po-file "work/compendium.pot")
(find-file my-po-file)
(load "po-mode")
(po-mode)

;;todo#1
					;ヘッダーはmsgidが""
(assert (string= (po-get-msgid) ""))

					;po-modeではたとえ入力に
					;poヘッダーが無くても
					;第1エントリーとしてpoヘッダーが
					;追加されるので読まない
(condition-case err
    (while (po-next-entry)

      (goto-char po-start-of-entry)
      (if (re-search-forward "^#:" po-end-of-entry t)
	  (let (name line)
            (while (looking-at "\\(\n#:\\)? *\\([^: ]*\\):\\([0-9]+\\)")
	      (goto-char (match-end 0))
	      (setq name (file-name-nondirectory (po-match-string 2))
                    line (po-match-string 3))
					;変更箇所参照用(全エントリー)
	      (setq commstr (concat name ":" line))
					;変更内容参照用(fuzzyエントリーのみ)
	      (if (eq po-entry-type 'fuzzy)
					;新msgid取得
		  (progn
		    (po-find-span-of-entry)
		    (setq current-msgid (po-get-msgid)
			  new-file "new_msgid.txt")
		    (with-temp-file new-file (insert current-msgid))
					;旧msgid取得
		    (po-find-span-of-entry)
		    (setq previous-msgid (my-po-get-previous-msgid 0)
			  old-file "old_msgid.txt")
		    (with-temp-file old-file (insert previous-msgid))
					;wdiff-ing
		    (shell-command (format "wdiffhtml %s %s >%s"
					   old-file new-file
					   (format "%s_%s.html"
						   name line)))
					;コメント編集
	      (po-edit-comment)
	      (erase-buffer)
	      (insert commstr)
	      (po-subedit-exit)))))))
  (error err
	 (progn
	   (if (string= (error-message-string err)
			"There is no such entry")
	       (save-buffer)
	     (signal (car err) (cdr err))))))
