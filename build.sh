#!/bin/bash
set -x
set -e
set -v

CM_EXT_BRANCH=cm6-6.1.0
FLINK_URL=http://mirrors.tuna.tsinghua.edu.cn/apache/flink/flink-1.9.0/flink-1.9.0-bin-scala_2.12.tgz 
#FLINK_MD5='903307847493610c8006992c5eae64a1'
FLINK_VERSION=1.9.0
EXTENS_VERSION=BIN-SCALA_2.12
OS_VERSION=7
CDH_MIN_FULL=5.2
CDH_MIN=5
CDH_MAX_FULL=6.2
CDH_MAX=6
flink_service_name="FLINK"
flink_service_name_lower="$( echo $flink_service_name | tr '[:upper:]' '[:lower:]' )"
flink_archive="$( basename $FLINK_URL )"
flink_unzip_folder="${flink_service_name_lower}-${FLINK_VERSION}"
flink_folder_lower="$( basename $flink_archive .tgz )"
flink_parcel_folder="$( echo $flink_folder_lower | tr '[:lower:]' '[:upper:]')"
flink_parcel_name="$flink_parcel_folder-el${OS_VERSION}.parcel"
flink_built_folder="${flink_parcel_folder}_build"
flink_csd_build_folder="flink_csd_build"

function build_cm_ext {  #Checkout if dir does not exist
  if [ ! -d cm_ext ]; then
    git clone https://github.com/cloudera/cm_ext.git
  fi
  if [ ! -f cm_ext/validator/target/validator.jar ]; then
    cd cm_ext
    #git checkout "$CM_EXT_BRANCH"
    mvn install -Dmaven.test.skip=true
    cd ..
  fi
}

function get_flink {
  if [ ! -f "$flink_archive" ]; then
    wget $FLINK_URL
  fi
  #flink_md5="$( md5sum $flink_archive | cut -d' ' -f1 )"
  #if [ "$flink_md5" != "$FLINK_MD5" ]; then
   # echo ERROR: md5 of $flink_archive is not correct
    #exit 1
  #fi
  if [ ! -d "$flink_unzip_foleder" ]; then
    tar -xvf $flink_archive
  fi
}

function build_flink_parcel {
  if [ -f "$flink_built_folder/$flink_parcel_name" ] && [ -f "$flink_built_folder/manifest.json" ]; then
    return
  fi
  if [ ! -d $flink_parcel_folder ]; then
    get_flink
    mkdir -p $flink_parcel_folder/lib
    sleep 3
    echo ${flink_unzip_folder}
    mv ${flink_unzip_folder}  ${flink_parcel_folder}/lib/${flink_service_name_lower}
  fi
  cp -r flink-parcel-src/meta $flink_parcel_folder/
  cp -r flink-parcel-src/flink-master.sh ${flink_parcel_folder}/lib/${flink_service_name_lower}/bin/
  cp -r flink-parcel-src/flink-worker.sh ${flink_parcel_folder}/lib/${flink_service_name_lower}/bin/
  cp -r flink-parcel-src/flink-yarn.sh ${flink_parcel_folder}/lib/${flink_service_name_lower}/bin/
  sed -i -e "s/%flink_version%/$flink_parcel_folder/" ./$flink_parcel_folder/meta/flink_env.sh
  sed -i -e "s/%VERSION%/$FLINK_VERSION/" ./$flink_parcel_folder/meta/parcel.json
  sed -i -e "s/%EXTENS_VERSION%/$EXTENS_VERSION/" ./$flink_parcel_folder/meta/parcel.json
  sed -i -e "s/%CDH_MAX_FULL%/$CDH_MAX/" ./$flink_parcel_folder/meta/parcel.json
  sed -i -e "s/%CDH_MIN_FULL%/$CDH_MIN/" ./$flink_parcel_folder/meta/parcel.json
  sed -i -e "s/%SERVICENAME%/$flink_service_name/" ./$flink_parcel_folder/meta/parcel.json
  sed -i -e "s/%SERVICENAMELOWER%/$flink_service_name_lower/" ./$flink_parcel_folder/meta/parcel.json
  java -jar cm_ext/validator/target/validator.jar -d ./$flink_parcel_folder
  mkdir -p $flink_built_folder
  tar zcvhf ./$flink_built_folder/$flink_parcel_name $flink_parcel_folder --owner=root --group=root
  java -jar cm_ext/validator/target/validator.jar -f ./$flink_built_folder/$flink_parcel_name
  python cm_ext/make_manifest/make_manifest.py ./$flink_built_folder
  sha1sum ./$flink_built_folder/$flink_parcel_name |awk '{print $1}' > ./$flink_built_folder/${flink_parcel_name}.sha
}

function build_flink_csd_on_yarn {
  JARNAME=${flink_service_name}_ON_YARN-${FLINK_VERSION}.jar
  if [ -f "$JARNAME" ]; then
    return
  fi
  rm -rf ${flink_csd_build_folder}
  cp -rf ./flink-csd-on-yarn-src ${flink_csd_build_folder}
  sed -i -e "s/%SERVICENAME%/$livy_service_name/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%SERVICENAMELOWER%/$flink_service_name_lower/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%VERSIONS%/$FLINK_VERSION/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%CDH_MIN%/$CDH_MIN/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%CDH_MAX%/$CDH_MAX/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%SERVICENAMELOWER%/$flink_service_name_lower/" ${flink_csd_build_folder}/scripts/control.sh
  java -jar cm_ext/validator/target/validator.jar -s ${flink_csd_build_folder}/descriptor/service.sdl -l "SPARK_ON_YARN SPARK2_ON_YARN"
  jar -cvf ./$JARNAME -C ${flink_csd_build_folder} .
}

function build_flink_csd_standalone {
  JARNAME=${flink_service_name}-${FLINK_VERSION}.jar
  if [ -f "$JARNAME" ]; then
    return
  fi
  rm -rf ${flink_csd_build_folder}
  cp -rf ./flink-csd-standalone-src ${flink_csd_build_folder}
  sed -i -e "s/%VERSIONS%/$FLINK_VERSION/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%CDH_MIN%/$CDH_MIN/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%CDH_MAX%/$CDH_MAX/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%SERVICENAME%/$livy_service_name/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%SERVICENAMELOWER%/$flink_service_name_lower/" ${flink_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%SERVICENAMELOWER%/$flink_service_name_lower/" ${flink_csd_build_folder}/scripts/control.sh
  java -jar cm_ext/validator/target/validator.jar -s ${flink_csd_build_folder}/descriptor/service.sdl -l "SPARK_ON_YARN SPARK2_ON_YARN"
  jar -cvf ./$JARNAME -C ${flink_csd_build_folder} .
}

case $1 in
parcel)
  build_cm_ext
  build_flink_parcel
  ;;
csd_on_yarn)
  build_flink_csd_on_yarn
  ;;
csd_standalone)
  build_flink_csd_standalone
  ;;
*)
  echo "Usage: $0 [parcel|csd_on_yarn|csd_standalone]"
  ;;
esac

