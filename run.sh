#!/usr/bin/env bash

DIR_PATH="$( cd "$( echo "${0%/*}" >> /dev/null )"; pwd )"
if [[ $DIR_PATH == */* ]]; then
	cd $DIR_PATH
fi

source run.conf

have_docker_container_name ()
{
	NAME=$1

	if [[ -n $(docker ps -a | awk '{ print $NF; }' | grep -e "^${NAME}$") ]]; then
		return 0
	else
		return 1
	fi
}

is_docker_container_name_running ()
{
	NAME=$1

	if [[ -n $(docker ps | awk '{ print $NF; }' | grep -e "^${NAME}$") ]]; then
		return 0
	else
		return 1
	fi
}

remove_docker_container_name ()
{
	NAME=$1

	if have_docker_container_name ${NAME} ; then
		if is_docker_container_name_running ${NAME} ; then
			echo Stopping container ${NAME}...
			(docker stop ${NAME})
		fi
		echo Removing container ${NAME}...
		(docker rm ${NAME})
	fi
}

# Configuration volume
if [ ! "${VOLUME_CONFIG_NAME}" == "$(docker ps -a | grep -v -e \"${VOLUME_CONFIG_NAME}/.*,.*\" | grep -e '[ ]\{1,\}'${VOLUME_CONFIG_NAME} | grep -o ${VOLUME_CONFIG_NAME})" ]; then
(
CONTAINER_MOUNT_PATH_CONFIG=${MOUNT_PATH_CONFIG}/${SERVICE_UNIT_NAME}.${SERVICE_UNIT_SHARED_GROUP}

# The Docker Host needs the target configuration directory
if [ ! -d ${HOST_PATH_CONFIG} ]; then
       CMD=$(mkdir -p ${HOST_PATH_CONFIG})
       $CMD || sudo $CMD
fi

if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/ssh ]; then
       CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG}/ssh)
       $CMD || sudo $CMD
fi

if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG}/ssh -maxdepth 1 -type f) ]]; then
       CMD=$(cp -R etc/services-config/ssh/ ${CONTAINER_MOUNT_PATH_CONFIG}/ssh/)
       $CMD || sudo $CMD
fi

if [ ! -d ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor ]; then
       CMD=$(mkdir -p ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor)
       $CMD || sudo $CMD
fi

if [[ ! -n $(find ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor -maxdepth 1 -type f) ]]; then
       CMD=$(cp -R etc/services-config/supervisor/ ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor/)
       $CMD || sudo $CMD
fi

set -x
docker run \
	--name ${VOLUME_CONFIG_NAME} \
       -v ${CONTAINER_MOUNT_PATH_CONFIG}/ssh:/etc/services-config/ssh \
       -v ${CONTAINER_MOUNT_PATH_CONFIG}/supervisor:/etc/services-config/supervisor \
	busybox:latest \
	/bin/true;
)
fi

# Force replace container of same name if found to exist
remove_docker_container_name ${DOCKER_NAME}

# In a sub-shell set xtrace - prints the docker command to screen for reference
(
set -x
docker run \
	-d \
	--name ${DOCKER_NAME} \
	-p :22 \
	--volumes-from ${VOLUME_CONFIG_NAME} \
	${DOCKER_IMAGE_REPOSITORY_NAME}
)

if is_docker_container_name_running ${DOCKER_NAME} ; then
	docker ps | grep -v -e "${DOCKER_NAME}/.*,.*" | grep ${DOCKER_NAME}
	echo " ---> Docker container running."
fi
