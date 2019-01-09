(setq my-po-file "work/compendium.po")

;;https://emacs.stackexchange.com/questions/22079/how-to-write-assertions
(defmacro assert (test-form)
  `(when (not ,test-form)
     (error "Assertion failed: %s" (format "%s" ',test-form)))) 

(defun my-replace-punctuation-like-texi2any (pun str)
  (replace-regexp-in-string
   pun
   (format "_%04x" (string-to-char pun))
   str))

(find-file my-po-file)

					;po-modeは絶対ある
					;(だって自分の翻訳環境だから)
;;(po-mode)

					;ヘッダーはmsgid=""
(assert (string= (po-get-msgid) ""))

					;po-modeではたとえ入力に
					;poヘッダーが無くても
					;第1エントリーとしてpoヘッダーが
					;追加されるので読まない
(while (po-next-entry)
  (goto-char po-start-of-entry)
  (if (re-search-forward "^#:" po-end-of-entry t)
      (let (name line path file)
        (while (looking-at "\\(\n#:\\)? *\\([^: ]*\\):\\([0-9]+\\)")
	  (goto-char (match-end 0))
	  (setq name (po-match-string 2)
                line (po-match-string 3))
	  (find-file name)
	  (goto-line (string-to-number line))
	  (beginning-of-line)
	  (insert "@anchor{" (concat name ":" line) "} ")
	  (save-buffer)
	  (kill-buffer)
	  
	  (po-edit-comment)
	  (insert (concat name ":" line))
	  (po-subedit-exit)))))




					;       



