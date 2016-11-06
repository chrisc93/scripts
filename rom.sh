#!/bin/bash
#
# ROM compilation script
#
# Copyright (C) 2016 Nathan Chancellor
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


###########
#         #
#  USAGE  #
#         #
###########

# $ rom.sh <rom> <device> (person)


############
#          #
#  COLORS  #
#          #
############

RED="\033[01;31m"
BLINK_RED="\033[05;31m"
RESTORE="\033[0m"


###############
#             #
#  FUNCTIONS  #
#             #
###############

# PRINTS A FORMATTED HEADER TO POINT OUT WHAT IS BEING DONE TO THE USER
function echoText() {
   echo -e ${RED}
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e "==  ${1}  =="
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e ${RESTORE}
}


# CREATES A NEW LINE IN TERMINAL
function newLine() {
   echo -e ""
}


################
#              #
#  PARAMETERS  #
#              #
################

# UNASSIGN FLAGS AND RESET ROM_BUILD_TYPE
unset ROM_BUILD_TYPE
PERSONAL=false
SUCCESS=false

while [[ $# -ge 1 ]]; do
   case "${1}" in
      "flash"|"pn"|"uber")
         ROM=${1}
         DEVICE=bullhead ;;
      *)
         echo "Invalid parameter detected!" && exit ;;
   esac

   shift
done

# PARAMETER VERIFICATION
if [[ -z ${DEVICE} || -z ${ROM} ]]; then
   echo "You did not specify a ROM. Please re-run the script with the necessary parameters!" && exit
fi

###############
#             #
#  VARIABLES  #
#             #
###############

# ANDROID_DIR: Directory that holds all of the Android files (currently my home directory)
# OUT_DIR: Directory that holds the compiled ROM files
# SOURCE_DIR: Directory that holds the ROM source
# ZIP_MOVE: Directory to hold completed ROM zips
# ZIP_FORMAT: The format of the zip file in the out directory for moving to ZIP_MOVE
ANDROID_DIR=/android
ZIP_MOVE_PARENT=/media/data/Media/www/builds.csconley.com/public_html

# Otherwise, define them for our various ROMs
case "${ROM}" in
   "flash")
      SOURCE_DIR=${ANDROID_DIR}/flash
      ZIP_MOVE=${ZIP_MOVE_PARENT}/flash
      ZIP_FORMAT=flash_${DEVICE}-7*.zip ;;
   "pn")
      SOURCE_DIR=${ANDROID_DIR}/pure_nexus
      ZIP_MOVE=${ZIP_MOVE_PARENT}/pure_nexus
      ZIP_FORMAT=pure_nexus_${DEVICE}-7*.zip ;;
   "uber")
      SOURCE_DIR=${ANDROID_DIR}/uber
      ZIP_MOVE=${ZIP_MOVE_PARENT}/uber
      ZIP_FORMAT=uber_${DEVICE}-7*.zip ;;
esac

OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}
THREADS_FLAG=-j$( grep -c ^processor /proc/cpuinfo )



################
# SCRIPT START #
################

clear


#######################
# START TRACKING TIME #
#######################

echoText "SCRIPT STARTING AT $( TZ=MST date +%D\ %r )"

START=$( TZ=MST date +%s )


###########################
# MOVE INTO SOURCE FOLDER #
###########################

echoText "MOVING TO SOURCE DIRECTORY"

cd ${SOURCE_DIR}


#############
# REPO SYNC #
#############

echoText "SYNCING LATEST SOURCES"; newLine

repo sync --force-sync ${THREADS_FLAG}


###########################
# SETUP BUILD ENVIRONMENT #
###########################

echoText "SETTING UP BUILD ENVIRONMENT"; newLine

# CHECK AND SEE IF WE ARE ON ARCH; IF SO, ACTIVARE A VIRTUAL ENVIRONMENT FOR PROPER PYTHON SUPPORT
if [[ -f /etc/arch-release ]]; then
   virtualenv2 venv
   source venv/bin/activate
fi

source build/envsetup.sh


##################
# PREPARE DEVICE #
##################

echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"; newLine

# NOT ALL ROMS USE BREAKFAST
case "${ROM}" in
   "maple")
      lunch maple_${DEVICE}-userdebug ;;
   "saosp")
      lunch saosp_${DEVICE}-user ;;
   "aosip")
      lunch aosip_${DEVICE}-userdebug ;;
   *)
      breakfast ${DEVICE} ;;
esac


############
# CLEAN UP #
############

echoText "CLEANING UP OUT DIRECTORY"; newLine

make clobber


##################
# START BUILDING #
##################

echoText "MAKING ZIP FILE"; newLine

NOW=$( TZ=MST date +"%Y-%m-%d-%S" )

# NOT ALL ROMS USE MKA OR BACON
case "${ROM}" in
   "saosp")
      time make otapackage ${THREADS_FLAG} 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log ;;
   "aosip")
      time make kronic ${THREADS_FLAG} 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log ;;
   *)
      time mka bacon 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log ;;
esac


###################
# IF ROM COMPILED #
###################

# THERE WILL BE A ZIP IN THE OUT FOLDER IN THE ZIP FORMAT
if [[ $( ls ${OUT_DIR}/${ZIP_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
   # MAKE BUILD RESULT STRING REFLECT SUCCESSFUL COMPILATION
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"
   SUCCESS=true


   ##################
   # ZIP_MOVE LOGIC #
   ##################

   # MAKE ZIP_MOVE IF IT DOESN'T EXIST OR CLEAN IT IF IT DOES
   if [[ ! -d "${ZIP_MOVE}" ]]; then
      newLine; echoText "MAKING ZIP_MOVE DIRECTORY"

      mkdir -p "${ZIP_MOVE}"
   fi


   ####################
   # MOVING ROM FILES #
   ####################

   newLine; echoText "MOVING FILES TO ZIP_MOVE DIRECTORY"; newLine

   mv -v ${OUT_DIR}/*${ZIP_FORMAT} "${ZIP_MOVE}"

   LATEST_ZIP=$(ls ${ZIP_MOVE} -tp | grep -v /$ | head -1)


###################
# IF BUILD FAILED #
###################

else
   BUILD_RESULT_STRING="BUILD FAILED"
   SUCCESS=false
fi



# DEACTIVATE VIRTUALENV IF WE ARE ON ARCH
if [[ -f /etc/arch-release ]]; then
   echoText "EXITING VIRTUAL ENV"
   deactivate
fi



##############
# SCRIPT END #
##############

END=$( TZ=MST date +%s )
newLine; echoText "${BUILD_RESULT_STRING}!"


######################
# ENDING INFORMATION #
######################

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION, AND SIZE
if [[ ${SUCCESS} = true ]]; then
   echo -e ${RED}"FILE LOCATION: $( ls ${ZIP_MOVE}/${LATEST_ZIP} )"
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RESTORE}; newLine


##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
case ${PERSONAL} in
   "true")
      echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} me" >> ${LOG} ;;
   *)
      echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} ${DEVICE}" >> ${LOG} ;;
esac

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
echo -e "${BUILD_RESULT_STRING} IN $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
   # FILE LOCATION: <PATH>
   echo -e "FILE LOCATION: $( ls ${ZIP_MOVE}/${LATEST_ZIP} )" >> ${LOG}
fi


########################
# ALERT FOR SCRIPT END #
########################

echo -e "\a" && cd ${HOME}
