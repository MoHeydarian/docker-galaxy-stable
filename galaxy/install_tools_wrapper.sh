#!/bin/bash

# Enable Test Tool Shed
echo "Enable installation from the Test Tool Shed."
export GALAXY_CONFIG_TOOL_SHEDS_CONFIG_FILE=$GALAXY_HOME/tool_sheds_conf.xml

if pgrep "supervisord" > /dev/null
then
    echo "System is up and running. Starting with the installation."
    export PORT=80
else
    # start Galaxy
    export PORT=8080
    service postgresql start
    install_log='galaxy_install.log'

    # wait for database to finish starting up
    STATUS=$(psql 2>&1)
    while [[ ${STATUS} =~ "starting up" ]]
    do
      echo "waiting for database: $STATUS"
      STATUS=$(psql 2>&1)
      sleep 1
    done

    echo "starting Galaxy"
    sudo -E -u galaxy ./run.sh -d $install_log --pidfile galaxy_install.pid --http-timeout 3000

    galaxy_install_pid=`cat galaxy_install.pid`
    galaxy-wait -g http://localhost:$PORT -v --timeout 120
fi

shed-tools install -g "http://localhost:$PORT" -a admin -t "$1"

exit_code=$?

if [ $exit_code != 0 ] ; then
    if [ "$2" == "-v" ] ; then
        echo "Installation failed, Galaxy server log:"
        cat $install_log
    fi
    exit $exit_code
fi

if ! pgrep "supervisord" > /dev/null
then
    # stop everything
    sudo -E -u galaxy ./run.sh --stop --pidfile galaxy_install.pid
    rm $install_log
    service postgresql stop
fi
