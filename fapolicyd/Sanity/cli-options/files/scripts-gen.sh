#!/bin/bash
gen() {
  local type1 type2 interpreter prefix prefix2
  type1="${1/\/*}"
  type2="${1#*\/}"
  shift
  while [[ -n "$1" ]]; do
    interpreter="$1"
    shift
#      'env /bin/env ' \
    for prefix in \
      'bin /bin/' \
      'usr-bin /usr/bin/' \
      'usr-env /usr/bin/env ' \
      ;
    do
      prefix2="${prefix#* }"
      prefix="${prefix/ *}"
      cat > ${type1}_${type2}_${prefix}-${interpreter} <<EOF
#!${prefix2}${interpreter}
EOF
    done
  done
}

gen 'text/x-lua' lua
gen 'text/x-python' python python2 python3
cat > text_x-python_bin-platform-python <<EOF
#!/usr/libexec/platform-python
EOF
gen 'text/x-shellscript' bash sh zsh
gen 'text/x-tcl' tclsh wish
