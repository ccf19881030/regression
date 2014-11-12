#!/bin/sh

#~ Copyright Rene Rivera 2014
#~ Distributed under the Boost Software License, Version 1.0.
#~ (See accompanying file LICENSE_1_0.txt or http://www.boost.org/LICENSE_1_0.txt)

set -e

build_all()
{
	build_setup
    update_tools
    time build_results develop 2>&1 | tee boost-reports/develop.log
    time build_results master 2>&1 | tee boost-reports/master.log
    upload_results develop
    upload_results master
}

git_update()
{
	cwd=`pwd`
	if [ -d "${1}" ]; then
		cd "${1}"
		git remote set-branches --add origin "${2}"
		git pull
		git checkout "${2}"
		git submodule update --init
	else
		mkdir -p "${1}"
		git init "${1}"
		cd "${1}"
		git remote add --no-tags -t "${2}" origin "${3}"
		git fetch --depth=1
		git checkout "${2}"
		git submodule update --init
	fi
	cd "${cwd}"
}

build_setup()
{
	cwd=`pwd`
	mkdir -p boost-reports/develop
	mkdir -p boost-reports/master
	git_update "${cwd}/boost-reports/boost_root" master 'https://github.com/boostorg/boost.git'
	git_update "${cwd}/boost-reports/boost_regression" develop 'https://github.com/boostorg/regression.git'
	cd "${cwd}"
}

update_tools()
{
    cwd=`pwd`
    cd "${cwd}/boost-reports/boost_root"
    ./bootstrap.sh
    cd "${cwd}/boost-reports/boost_regression/build"
    "${cwd}/boost-reports/boost_root/b2" install
    cd "${cwd}"
}

report_info()
{
cat - > comment.html <<HTML
<table style="border-spacing: 0.5em;">
    <tr>
        <td style="vertical-align: top;"><tt>uname</tt></td>
        <td>
            <pre style="border: 1px solid #666; overflow: auto;">
`uname -a`
            </pre>
        </td>
    </tr>
    <tr>
        <td style="vertical-align: top;"><tt>uptime</tt></td>
        <td>
            <pre style="border: 1px solid #666; overflow: auto;">
`uptime`
            </pre>
        </td>
    </tr>
    <tr>
        <td style="vertical-align: top;"><tt>python</tt></td>
        <td>
            <pre style="border: 1px solid #666; overflow: auto;">
`python --version 2>&1`
            </pre>
        </td>
    </tr>
    <tr>
        <td style="vertical-align: top;">previous run</td>
        <td>
            <pre style="border: 1px solid #666; overflow: auto;">
`cat previous.txt`
            </pre>
        </td>
    </tr>
    <tr>
        <td style="vertical-align: top;">current run</td>
        <td>
            <pre style="border: 1px solid #666; overflow: auto;">
`date -u`
            </pre>
        </td>
    </tr>
</table>
HTML
    date -u > previous.txt
}

build_results()
{
    tag="${1?'error: command line missing branch-name argument'}"
    reports="dd,ds,i,n"
    cwd=`pwd`
    cd boost-reports
    cd "${1}"
    root=`pwd`
    boost=${cwd}/boost-reports/boost_root
    report_info
    python "${cwd}/boost_regression/xsl_reports/boost_wide_report.py" \
        --locate-root="${root}" \
        --tag=${tag} \
        --expected-results="${boost}/status/expected_results.xml" \
        --failures-markup="${boost}/status/explicit-failures-markup.xml" \
        --comment="comment.html" \
        --user="" \
        --reports=${reports} \
        "--boost-report=${cwd}/boost_regression/build/bin/boost_report"
    cd "${cwd}"
}

upload_results()
{
    cwd=`pwd`
    cd boost-reports
    upload_dir=/home/grafik/www.boost.org/testing
    
    if [ -f ${1}/report.zip ]; then
        mv ${1}/report.zip ${1}.zip
    else
        cd ${1}/all
        rm -f ../../${1}.zip*
        #~ zip -q -r -9 ../../${1} * -x '*.xml'
        7za a -tzip -mx=9 ../../${1}.zip * '-x!*.xml'
        cd "${cwd}"
    fi
    mv ${1}.zip ${1}.zip.uploading
    rsync -vuz --rsh=ssh --stats \
      ${1}.zip.uploading grafik@beta.boost.org:/${upload_dir}/incoming/
    ssh grafik@beta.boost.org \
      cp --no-preserve=timestamps ${upload_dir}/incoming/${1}.zip.uploading ${upload_dir}/live/${1}.zip
    mv ${1}.zip.uploading ${1}.zip
    cd "${cwd}"
}

build_all 2>&1 | tee boost-reports.log