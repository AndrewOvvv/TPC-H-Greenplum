#!/bin/sh

RESULTS=results
HOST=$1
DBNAME=$2
USER=$3
PWD=$4
# delay between stats collections (iostat, vmstat, ...)
DELAY=15

# DSS queries timeout (5 minutes or something like that)
DSS_TIMEOUT=300000 # 5 minutes in seconds

# log
LOGFILE=bench.log

function benchmark_run() {
	mkdir -p $RESULTS

	# store the settings
	psql -h $HOST -U $USER postgres -c "select name,setting from pg_settings" > $RESULTS/settings.log 2> $RESULTS/settings.err
	print_log "preparing TPC-H database"

	# create database, populate it with data and set up foreign keys
	print_log "  loading data"
	psql -h $HOST -U $USER $DBNAME < dss/tpch-load.sql > $RESULTS/load.log 2> $RESULTS/load.err

	print_log "  creating primary keys"
	psql -h $HOST -U $USER $DBNAME < dss/tpch-pkeys.sql > $RESULTS/pkeys.log 2> $RESULTS/pkeys.err

	print_log "  creating foreign keys"
	psql -h $HOST -U $USER $DBNAME < dss/tpch-alter.sql > $RESULTS/alter.log 2> $RESULTS/alter.err

	print_log "  creating indexes"
	psql -h $HOST -U $USER $DBNAME < dss/tpch-index.sql > $RESULTS/index.log 2> $RESULTS/index.err

	print_log "  analyzing"
	psql -h $HOST -U $USER $DBNAME < dss/tpch-analyze.sql > $RESULTS/analyze.log 2> $RESULTS/analyze.err

	print_log "finished"
}

function load_data_start()
{
	local RESULTS=$1
	# run some basic monitoring tools (iotop, iostat, vmstat)
	for dev in $DEVICES
	do
		iostat -t -x /dev/$dev $DELAY >> $RESULTS/iostat.$dev.log &
	done;
	vmstat $DELAY >> $RESULTS/vmstat.log &

}

function load_data_stop()
{
	# wait to get a complete log from iostat etc. and then kill them
	sleep $DELAY
	for p in `jobs -p`; do
		kill $p;
	done;

}

function print_log() {
	local message=$1
	echo `date +"%Y-%m-%d %H:%M:%S"` "["`date +%s`"] : $message" >> $RESULTS/$LOGFILE;
	echo `date +"%Y-%m-%d %H:%M:%S"` "["`date +%s`"] : $message";

}

mkdir $RESULTS;
export PGPASSWORD=$PWD
# start statistics collection
load_data_start $RESULTS
# run the benchmark
benchmark_run $RESULTS $DBNAME $USER
# stop statistics collection
load_data_stop
