import json
from fabric import api

CLUSTER_HOSTNAME='127.0.0.1'
COOKIE = "AmbientCalculus"
DEFAULT_MIX_CMD = "mix run --no-halt"

def consul():
    cmd = "docker run {name} -it {net} {env} consul agent {dp} {bind}"
    cmd = cmd.format(
        name="--name ambient-consul",
        net="--net=host",
        env="-e 'CONSUL_LOCAL_CONFIG=`cat consul.config`' ",
        dp='-dp 8500:8500/tcp',
        bind="-bind={external_ip}".format(
            external_ip="0.0.0.0"),
    )
    api.local(cmd)
def slp_daemon_start():
    cmd = ("docker run -d "
           "-p 427:427/tcp "
           "-p 427:427/udp "
           "--name openslp vcrhonek/openslp")
    api.local(cmd)

def slp_daemon_stop():
    cmd = ("docker rm -f openslp")
    api.local(cmd)

def slp_list():
    api.local("slptool findsrvs exslp")

def slp_flush():
    api.local("")

def shell(name='AmbientShell', erl_config='shell.config'):
    ambient_cluster(
        name=name,
        mix_cmd='mix run', erl_config=erl_config)

DEFAULT_ERL_CONFIG = "sys.config"
def ambient_cluster(name='u1', erl_config=None, mix_cmd=None):
    erl_config = erl_config or DEFAULT_ERL_CONFIG
    mix_cmd = mix_cmd or DEFAULT_MIX_CMD
    cmd = "iex --name {name}@{hostname} {opts} {mix_cmd}"
    api.local(
        cmd.format(
            mix_cmd = mix_cmd,
            opts=" --erl \"-config {0}\" -S ".format(erl_config),
            cookie=COOKIE, name=name,
            hostname=CLUSTER_HOSTNAME))

def stop_cluster(node):
     cmd = ('erl -name "shutdown@{hostname}" -setcookie {cookie}'
         "-noinput -eval "
         '"rpc:call(\'{node}\', init, stop, []), init:stop()."')
     cmd = cmd.format(
         node=node,
         hostname=CLUSTER_HOSTNAME, cookie=COOKIE)
     print cmd
