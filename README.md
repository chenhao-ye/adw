# Artifact Demonstration Wizard

Artifact Demonstration Wizard (ADW) is a framework to demonstrate the workflow of a project.

ADW is designed to tackle these troublesome scenarios:

- The codebase is supposed to be built with configuration A for experiment 1 and with configuration B for experiment 2. You just finished experiment 1. Then you start experiment 2 but you forget to rebuild the codebase with configuration B. As a consequence, it produces some garbage outputs so you have to rerun it, in the best case; in the worst case, you never realize this is garbage output...

- You have several experiments to run and you start one of them. The experiment takes hours, so you decide to switch to YouTube when waiting (it's fully justified, right?). Hours later, you pause YouTube and want to check out the experiment results, but you forget which experiment you started hours ago...

- You run an experiment several times and each generates a directory for its output logs. Then you have a set of log directories, but every time when you (or likely, your log parser script) want to take a look, you have to figure out which one is the latest.

- You run an experiment several times on a few branches. A week later, you track down a problem and want to see if it presented in a branch's log earlier. However, you have no way to tell which log was from which branch's code. Literally, no way.

If any problem above had troubled you, you will probably like ADW.

## Install

To install adw:

```bash
./install.sh
echo 'export ADW_HOME="$HOME/.adwarts"' >> .bashrc # or .zshrc
echo 'export PATH="$PATH:$ADW_HOME/bin"' >> .bashrc
```

This will install adw codebase to `~/.adwarts`. To uninstall:

```bash
./install.sh -u
```

## Overview

To begin with, the user provides a configuration file `adw.yaml`, located at the top-level directory of a codebase (just like `Dockerfile` and `Makefile`). `adw.yaml` describes the workflow of this codebase and what scripts to run for every path of workload. The detailed tutorials of `adw.yaml` can be found [here](doc), and below only focuses on the semantics level and ignore syntax so far.

ADW uses a restricted workflow model named "predicates and multilevel targets." To begin with, suppose you have developed a novel user-level filesystem called uFS (you can learn more story of uFS in [a later section](#why-adw)). Now you want to automate the workflow of building and benchmarking uFS and ext4 against LevelDB workload. The workflow could be divided into three steps: `init`, `build`, and `run`. We call these steps "predicates". Each predicate has a set of targets. The hierarchy relationship is shown below and we will walk through it.

```
+- init
+- build
|    +- leveldb
|         +- ufs
|         +- ext4
+- run
     +- leveldb
          +- ufs
          |    +- ycsb-a
          |    +- ycsb-b
          |    +- ycsb-c
          +- ext4
               +- ycsb-a
               +- ycsb-b
               +- ycsb-c
```

For the tree above, the user provide a script for each leaf node (e.g. `init`, `build/leveldb/ufs`, `run/leveldb/ext4/ycsb-a`) in `adw.yaml` indicate the action for this path.

For predicate `init`, all you want is some system-wide setting (e.g. set a fixed CPU frequency); it doesn't matter whether it is initialized for uFS or ext4. We say this predicate has no target and itself is a leaf node. By running this command, adw invoke the script for initialization:

```bash
adw init
```

For `build` and `run`, there are specific patterns to do the job. First, when benchmarking against LevelDB workload, you want to specify whether build LevelDB with uFS's APIs or ext4's APIs. The corresponds to two targets `leveldb/ufs` and `leveldb/ext4`. We call them "multilevel targets" since they are both subtargets of `leveldb`. To compile LevelDB with uFS's APIs (again, this is a leaf node on the tree above):

```bash
adw build leveldb ufs
```

Now you want to run LevelDB, and you have multiple input traces to feed (e.g. `ycsb-a` to `ycsb-c`). To feed `ycsb-a`:

```bash
adw run leveldb ufs ycsb-a
```

At this point, you are free to feed any traces as long as they are subtargets of `leveldb/ufs`. However, if you try to run leveldb on ext4:

```console
$ adw run leveldb ext4
ADW: Execution rejected: run/leveldb/ext4/ycsb-a
  Dependencies unsatisfied:
    - build/leveldb/ext4
```

You get rejected because you have never built LevelDB using ext4's APIs. This is captured by the dependency rule: **Executing a leaf node requires the successful execution of the same leaf node on the previous predicate; if the current leaf node doesn't present on the previous predicate, requires its longest (and only, actually), prefix that appears as a leaf.** In this example, `run/leveldb/ext4/ycsb-a` first requires the successful execution of `build/leveldb/ext4/ycsb-a`, but this target doesn't exist, so it requires its prefix `build/leveldb/ext4` instead, which is a leaf node. You may now notice that previously we can execute `build/leveldb/ufs` because of the success of `init`.

The dependency enforcement also provides a user-friendly help message for "what is expected next" if the user only provides a path that does not reach a leaf node:

```console
$ adw run leveldb
Usage: adw run leveldb {ext4|ufs} [...]

$ adw run leveldb ufs
Usage: adw run leveldb ufs {ycsb-a|ycsb-b|ycsb-c} [...]

$ adw run leveldb wrong_target
Usage: adw run leveldb {ext4|ufs} [...]
```

For fancier usage, you may want to pass some command-line arguments to some leaf node's action script.

```bash
adw run leveldb ufs ycsb-a --duration 20
```

ADW will recognize `run/leveldb/ufs/ycsb-a` reaches a leaf node, and then pass the rest of command-line arguments to the action script indicated by `run/leveldb/ufs/ycsb-a`.

For more advanced usage, you could set predicate `build` "exclusive": the successful execution of one leaf node under `build` will invalidate other success under `build`. For example, `build/leveldb/ufs` compiles LevelDB with uFS's APIs. Later if you execute `build/leveldb/ext4`, which recompiles LevelDB with ext4's APIs, the previous compilation's binary will be overwritten and the success of `build/leveldb/ufs` should be invalidated:

```console
$ adw build leveldb ufs
$ adw run leveldb ufs ycsb-a # OK
$ adw build leveldb ext4     # Exclusive predicate `build` invalidates build/leveldb/ufs
$ adw run leveldb ufs ycsb-a # NOT OK
ADW: Execution rejected: run/leveldb/ufs/ycsb-a
  Dependencies unsatisfied:
    - build/leveldb/ufs
```

Please checkout document for the detailed usage.

All commands that pass dependencies enforcement will be logged. The log includes start time, finish time, duration, git commit id, and the command's exit code.

```console
$ adw proj log # you could use `--less` or `--vim` to choose pager
Time:   2021-09-02 17:38:22 -> 2021-09-02 17:38:22 [0s]
Commit: 82a016f
Status: 0
Command: build leveldb ext4

Time:   2021-09-02 17:38:16 -> 2021-09-02 17:38:17 [1s]
Commit: 82a016f
Status: 0
Command: run leveldb ufs ycsb-a

Time:   2021-09-02 17:38:10 -> 2021-09-02 17:38:10 [0s]
Commit: 82a016f
Status: 0
Command: build leveldb ufs

Time:   2021-09-02 17:38:04 -> 2021-09-02 17:38:04 [0s]
Commit: 82a016f
Status: 0
Command: run leveldb ufs ycsb-a --duration 20

Time:   2021-09-02 17:37:49 -> 2021-09-02 17:37:49 [0s]
Commit: 82a016f
Status: 0
Command: run leveldb ufs ycsb-a

Time:   2021-09-02 17:37:38 -> 2021-09-02 17:37:38 [0s]
Commit: 82a016f
Status: 0
Command: build leveldb ufs

Time:   2021-09-02 17:37:27 -> 2021-09-02 17:37:27 [0s]
Commit: 82a016f
Status: 0
Command: init
```

This is a tiny function but turns out to be extremely useful.

## Why ADW

ADW was actually abstracted from [uFS](https://github.com/WiscADSL/uFS/tree/main/cfs_bench/exprs/artifact_eval)'s submission of artifact evaluation. We would like to automate the experiments to make reviewers' jobs easier. I realized a well-documented script can be as powerful as a detailed README: users can always track down the execution flow of the script to understand what should be done in what order (and know it actually works). Under this observation, `adw.yaml` is designed to be a document by itself. People should be able to read `adw.yaml` to gain a big picture of workflow quickly.
