import json
from fabric import api

CLUSTER_HOSTNAME='127.0.0.1'
COOKIE = "AmbientCalculus"
DEFAULT_MIX_CMD = "mix run --no-halt"

def observe():
    cmd = "iex --name AmbientObserver@127.0.0.1 -S mix observe"
    api.local(cmd)

def slp_flush():
    slp_daemon_stop()
    slp_daemon_start()
def slp_search():
    api.local('slptool findsrvs exslp')
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
    with api.settings(warn_only=True):
        slp_daemon_stop()
    slp_daemon_start()

def display(x=1):
    with api.shell_env(DISPLAY_LOOP="yes"):
        ambient_cluster(
            name='display')

def script(_script):
    ambient_cluster(
        name=name,
        mix_cmd='-S {0}'.format(_script))

def shell(name='AmbientShell'):
    ambient_cluster(
        name=name,
        mix_cmd='mix run')

DEFAULT_ERL_CONFIG = "sys.config"
def ambient_cluster(name='u1', mix_cmd=None):
    mix_cmd = mix_cmd or DEFAULT_MIX_CMD
    cmd = "iex --name {name}@{hostname} {opts} {mix_cmd}"
    api.local(
        cmd.format(
            mix_cmd = mix_cmd,
            opts="-S",# --erl \"-config {0}\" -S ".format(erl_config),
            cookie=COOKIE, name=name,
            hostname=CLUSTER_HOSTNAME))

def stop_cluster():
    NIY

def stop_node(node):
     node=node.replace('"','\"')
     cmd = "iex --name shutdown@{hostname} {opts} {mix_cmd}"
     api.local(
        cmd.format(
            mix_cmd = "mix run --eval 'Universe.shutdown_all_nodes()'",
            cookie=COOKIE,
            hostname=CLUSTER_HOSTNAME,
            opts=" -S ",
            node=node)),
