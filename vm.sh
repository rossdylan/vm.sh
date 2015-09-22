# Welcome to Episkopos!
# Now, I know you are all wondering what madness has crawled out of my twisted
# mind and into your computer. This is a register based virtual machine...
# written completely in bash.
# Don't look at me like that, its a great idea.
# Think of a world where bash is compiled to bash and run on bash. Its an endless
# recursive cycle. The name comes from discordianism, which I often turn to
# when I'm writing something particularlly nutty.
set -e
declare -A general_reg=(["r0"]=0 ["r1"]=0 ["r2"]=0 ["r3"]=0 ["r4"]=0 ["r5"]=0 ["ze"]=0 ["tr"]=1)
declare -A addr_reg=(["a0"]=0 ["a1"]=0 ["a2"]=0 ["a3"]=0 ["a4"]=0 ["a5"]=0)
declare -A special_reg=(["er"]=0 ["pc"]=0 ["sp"]=0 ["ex"]=0) # error, program counter, stack pointer
declare -A labels
declare -a stack


# For returning results from functions
result_var=0


function call() {
    stack=("${stack[@]}" ${special_reg["pc"]})
    jmp $1
}


function ret() {
    local before_sp=${special_reg["sp"]}
    special_reg["sp"]=$(expr $before_sp - 1)
    local sp=${special_reg["sp"]}
    local top=${stack[$sp]}
    stack=(${stack[@]:0:$((${#stack[@]}-1))})
    jmp $top
}

function push() {
    rega=${general_reg[$1]}
    stack=("${stack[@]}" $rega)
    special_reg["sp"]=$(expr ${special_reg["sp"]} + 1)
}

function pushall() {
    for reg in {0..5}; do
        push "r$reg"
    done
}

function pop() {
    local before_sp=${special_reg["sp"]}
    special_reg["sp"]=$(expr $before_sp - 1)
    local sp=${special_reg["sp"]}
    local top=${stack[$sp]}
    stack=(${stack[@]:0:$((${#stack[@]}-1))})
    general_reg[$1]=$top
}

function popall() {
    for reg in {0..5}; do
        local adjusted_reg=$(expr 5 - $reg)
        pop "r$adjusted_reg"
    done
}

function label() {
    labels[$1]=${special_reg["pc"]}
}

function loadi() {
    general_reg[$1]=$2
}

function loada() {
    local addr=$1
    if [[ $1 == :* ]] # its a label
    then
        local prefix=":"
        local lab="${1#$prefix}"
        addr_reg[$1]=${labels[$lab]}
    elif [[ $1 == +* ]] # relative, increasing
    then
        local prefix="+"
        local offset=${1#$prefix}
        local current=$(expr ${special_reg["pc"]} - 1)
        addr_reg[$1]=$(expr current + offset)
    elif [[ $1 == -* ]] # relative, decreasing
    then
        local prefix="-"
        local offset=${1#$prefix}
        local current=$(expr ${special_reg["pc"]} - 1)
        addr_reg[$1]=$(expr current - offset)
    fi
}

function addi() {
    general_reg[$1]=$(expr ${general_reg[$2]} + $3)
}
function add() {
    general_reg[$1]=$(expr ${general_reg[$2]} + ${general_reg[$3]})
}
function halt() {
    special_reg["ex"]=1
}
function jmp() {
    local addr=$1
    if [[ $1 == :* ]] # its a label
    then
        local prefix=":"
        local lab="${1#$prefix}"
        addr=${labels[$lab]}
    elif [[ $1 == +* ]] # relative, increasing
    then
        local prefix="+"
        local offset=${1#$prefix}
        local current=$(expr ${special_reg["pc"]} - 1)
        addr=$(expr current + offset)
    elif [[ $1 == -* ]] # relative, decreasing
    then
        local prefix="-"
        local offset=${1#$prefix}
        local current=$(expr ${special_reg["pc"]} - 1)
        addr=$(expr current - offset)
    elif [[ $1 == a* ]]
    then
        addr=${addr_reg[$1]}
    fi
    special_reg["pc"]=$addr
}
function jlt() {
    rega=${general_reg[$2]}
    regb=${general_reg[$3]}
    if [ $rega -lt $regb ]
    then
        jmp $1
    fi
}
function jlti() {
    rega=${general_reg[$2]}
    if [ $rega -lt $3 ]
    then
        jmp $1
    fi
}
function jgt() {
    rega=${general_reg[$2]}
    regb=${general_reg[$3]}
    if [ $rega -gt $regb ]
    then
        jmp $1
    fi
}
function jgti() {
    rega=${general_reg[$2]}
    if [ $rega -gt $3 ]
    then
        jmp $1
    fi
}
function je() {
    rega=${general_reg[$2]}
    regb=${general_reg[$3]}
    if [ $rega -eq $regb ]
    then
        jmp $1
    fi
}
function jei() {
    rega=${general_reg[$2]}
    if [ $rega -eq $3 ]
    then
        jmp $1
    fi
}


declare -A dispatch_map=(["loadi"]=loadi
                         ["addi"]=addi
                         ["add"]=add
                         ["halt"]=halt
                         ["jmp"]=jmp
                         ["jlt"]=jlt
                         ["jlti"]=jlti
                         ["jgt"]=jgt
                         ["jgti"]=jgti
                         ["je"]=je
                         ["jei"]=jei
                         ["loada"]=loada
                         ["label"]=label
                         ["push"]=push
                         ["pop"]=pop
                         ["pushall"]=pushall
                         ["popall"]=popall
                         ["call"]=call
                         ["ret"]=ret)

# Callback function for readarray that finds and evaluates labels
function label_scan_cb() {
    local line=$2
    if [[ "$line" == label* ]]
    then
        local jmpinst=( $line )
        local name=${jmpinst[1]}
        labels[$name]=$(expr $1 + 1)
    fi
}

# Fetch the current instruction pointed to by the pc register
function fetch() {
    local instr=${program[${special_reg["pc"]}]}
    special_reg["pc"]=$(expr 1 + ${special_reg["pc"]})
    result_var=( $instr )
}

# Main part of the run loop. Fetch an instruction, eval it
function dispatch() {
    fetch;
    if [ "$result_var" != "" ]
    then
        local cmd=${result_var[0]}
        local args=${result_var[@]:1}
        eval "${dispatch_map[$cmd]} $args"
    fi
}

############################
# Main Program Entry Point #
############################

readarray -t -C 'label_scan_cb' -c 1 program

echo "--- Initial State ---"
echo "General Registers:"
echo ${general_reg[@]}
echo "Special Registers:"
echo ${special_reg[@]}
echo "Labels:"
echo ${labels[@]}
echo "Stack:"
echo ${stack[@]}
echo "---------------------"

while true; do
    dispatch;
    if [ "${special_reg[ex]}" -eq 1 ] || [ "${special_reg[pc]}" -eq "${#program[@]}" ]
    then
        break;
    fi
done

echo "--- Final State -----"
echo "General Registers:"
echo ${general_reg[@]}
echo "Special Registers:"
echo ${special_reg[@]}
echo "Labels:"
echo ${labels[@]}
echo "Stack:"
echo ${stack[@]}
echo "---------------------"
