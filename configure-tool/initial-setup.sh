#!/bin/bash
workdir=$1
cd ${workdir}
/bin/bash ${workdir}/EulerOS_Reinforce/EulerReinforce.sh
/bin/python ${workdir}/osstdfix.py
