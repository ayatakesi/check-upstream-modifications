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
    BASE_DIR=$(pwd)
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
    cd ${BASE_DIR}
}

function check_po_state () {
    for PO in $(ls *.po)
    do
	STAT=$(msgfmt -v ${PO} 2>&1)
	printf "%s := %s\n" ${PO} "${STAT}"
    done
}

function after_translate () {
    cp ${NEW_DOC_DIR}/*.texi ${OLD_DOC_DIR}
    
    for PO in $(ls ${OLD_PO_DIR}/*.po)
    do
	F=$(basename ${PO})
	NEW_PO=${WORK_DIR}/${F}

	TRANS=$(mktemp)
	msgattrib --translated --force-po -o ${TRANS} ${NEW_PO}
	
	FUZZY=$(mktemp)
	msgattrib --only-fuzzy --clear-fuzzy --force-po ${NEW_PO} \
	    | msgfilter --keep-header --force-po -o ${FUZZY} sed -e 's/.*//'
	msgmerge --force-po --compendium ${COMPENDIUM} \
		 -o ${FUZZY}.translated /dev/null ${FUZZY}
	
	UNTRANS=$(mktemp)
	msgattrib --untranslated --force-po -o ${UNTRANS} ${NEW_PO}
	msgmerge --force-po --compendium ${COMPENDIUM} \
		 -o ${UNTRANS}.translated /dev/null ${UNTRANS}
	
	msgcat --force-po --no-wrap -F -o ${NEW_PO} \
	       ${TRANS} ${FUZZY}.translated ${UNTRANS}.translated
	
	rm ${TRANS} ${FUZZY}* ${UNTRANS}*
	cp ${NEW_PO} ${PO} && rm ${NEW_PO}
    done
}
