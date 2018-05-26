#!/bin/sh
OLD_PO_DIR=${HOME}/gitroot/emacs-26.1-doc-emacs/
OLD_DOC_DIR=${OLD_PO_DIR}/original_texis/
NEW_DOC_DIR=${HOME}/work/emacs/doc/emacs/
WORK_DIR="./"
COMPENDIUM=${WORK_DIR}/compendium.po
UPDATE_NEW_DOCS_CMD="git fetch ${NEW_DOC_DIR}/../.."
COMMIT_COMPENDIUM_CMD="git add -A; git commit -m 'update compendium'; git push -u origin master"
PUBLISH_LOC=${HOME}/gitroot/ayatakesi.github.io/emacs/

function before_translate () {
    PWD=$(pwd)
    eval ${UPDATE_NEW_DOCS_CMD}

    rm -i ${COMPENDIUM}

    for TEXI in $(ls ${NEW_DOC_DIR}/*.texi)
    do
	F=$(basename ${TEXI})
	POT="${WORK_DIR}/${F}.pot"
	OLD_PO="${OLD_PO_DIR}/${F}.po"        
	NEW_PO="${WORK_DIR}/${F}.po"
	
	if [ -f ${OLD_PO} ] ; then
	    po4a-gettextize -M utf8 -f texinfo \
			    -m ${TEXI} -p ${POT}
	    
	    msgmerge --previous --compendium ${OLD_PO} \
		     -o ${NEW_PO} /dev/null ${POT}

	    mv ${OLD_PO} ${OLD_PO}.bk && \
		cp ${NEW_PO} ${OLD_PO}
	    
	    FUZZY=$(mktemp)
	    msgattrib -o ${FUZZY} --only-fuzzy ${NEW_PO}
	    
	    UNTRANS=$(mktemp)
	    msgattrib -o ${UNTRANS} --untranslated ${NEW_PO}

	    msgcat -o ${NEW_PO}.compendium \
		   -F ${FUZZY} ${UNTRANS}
	    
	    rm -f ${FUZZY} ${UNTRANS}
	    
	fi

    done

    msgcat --no-wrap *.compendium  > ${COMPENDIUM}
    rm -f *.pot *.compendium

    msgcat --no-wrap --color=html ${COMPENDIUM} \
	   > ${COMPENDIUM}.html

    cp ${COMPENDIUM}.html ${PUBLISH_LOC}

    cd ${PUBLISH_LOC}
    eval ${COMMIT_COMPENDIUM_CMD}
    cd ${PWD}
}

function after_translate () {
    cp ${NEW_DOC_DIR}/*.texi ${OLD_DOC_DIR}
    
    for PO in $(ls ${OLD_PO_DIR}/*.po)
    do
	F=$(basename ${PO})
	NEW_PO=${WORK_DIR}/${F}
	POT=${NEW_PO}t
	
	msgmerge --previous --compendium ${COMPENDIUM} \
		 -o ${POT} /dev/null ${PO}
	
#	msgattrib --clear-previous --clear-fuzzy \
#		  -o ${NEW_PO} ${POT}
	rm ${POT}
	cp ${NEW_PO} ${PO} && rm ${NEW_PO}
    done
}
