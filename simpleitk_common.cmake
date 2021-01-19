# SimpleITK Common Dashboard Script
#
# This script contains basic dashboard driver code common to all
# clients.
#
# Put this script in a directory such as "~/Dashboards/Scripts" or
# "c:/Dashboards/Scripts".  Create a file next to this script, say
# 'my_dashboard.cmake', with code of the following form:
#
#   # Client maintainer: me@mydomain.net
#   set(CTEST_SITE "machine.site")
#   set(CTEST_BUILD_NAME "Platform-Compiler")
#   set(CTEST_BUILD_CONFIGURATION Debug)
#   set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
#   include(${CTEST_SCRIPT_DIRECTORY}/simpleitk_common.cmake)
#
# Then run a scheduled task (cron job) with a command line such as
#
#   ctest -S ~/Dashboards/Scripts/my_dashboard.cmake -V
#
# By default the source and build trees will be placed in the path
# "../My Tests/" relative to your script location.
#
# The following variables may be set before including this script
# to configure it:
#
#   dashboard_model           = Nightly | Experimental | Continuous
#   dashboard_track           = Optional track to submit dashboard to
#   dashboard_loop            = Repeat until N seconds have elapsed
#   dashboard_root_name       = Change name of "My Tests" directory
#   dashboard_source_name     = Name of source directory (SimpleITK)
#   dashboard_source_config_dir   = Name of subdirectory for configure
#   dashboard_binary_name     = Name of binary directory (SimpleITK-build)
#   dashboard_cache           = Initial CMakeCache.txt file content
#   dashboard_do_cache        = Always write CMakeCache.txt
#   dashboard_configure_options   = options pass to test
#   dashboard_do_coverage     = True to enable coverage (ex: gcov)
#   dashboard_do_memcheck     = True to enable memcheck (ex: valgrind)
#   dashboard_no_parts        = True to disable incremental submit
#   dashboard_no_clean        = True to skip build tree wipeout
#   dashboard_no_update       = True to skip source tree update
#   CTEST_UPDATE_COMMAND      = path to git command-line client
#   CTEST_BUILD_FLAGS         = build tool arguments (ex: -j2)
#   CTEST_DASHBOARD_ROOT      = Where to put source and build trees
#   CTEST_TEST_CTEST          = Whether to run long CTestTest* tests
#   CTEST_TEST_TIMEOUT        = Per-test timeout length
#   CTEST_TEST_ARGS           = ctest_test args (ex: PARALLEL_LEVEL 4)
#   CMAKE_MAKE_PROGRAM        = Path to "make" tool to use
#
# Options to configure builds from experimental git repository:
#   dashboard_git_url      = Custom git clone url
#   dashboard_git_branch   = Custom remote branch to track
#   dashboard_git_crlf     = Value of core.autocrlf for repository
#
# The following macros will be invoked before the corresponding
# step if they are defined:
#
#   dashboard_hook_init       = End of initialization, before loop
#   dashboard_hook_start      = Start of loop body, before ctest_start
#   dashboard_hook_build      = Before ctest_build
#   dashboard_hook_test       = Before ctest_test
#   dashboard_hook_coverage   = Before ctest_coverage
#   dashboard_hook_memcheck   = Before ctest_memcheck
#   dashboard_hook_submit     = Before ctest_submit
#   dashboard_hook_end        = End of loop body, after ctest_submit
#
# For Makefile generators the script may be executed from an
# environment already configured to use the desired compilers.
# Alternatively the environment may be set at the top of the script:
#
#   set(ENV{CC}  /path/to/cc)   # C compiler
#   set(ENV{CXX} /path/to/cxx)  # C++ compiler
#   set(ENV{FC}  /path/to/fc)   # Fortran compiler (optional)
#   set(ENV{LD_LIBRARY_PATH} /path/to/vendor/lib) # (if necessary)

cmake_minimum_required(VERSION 3.10 FATAL_ERROR)

set(dashboard_user_home "$ENV{HOME}")

get_filename_component(dashboard_self_dir ${CMAKE_CURRENT_LIST_FILE} PATH)

# Select the top dashboard directory.
if(NOT DEFINED dashboard_root_name)
  set(dashboard_root_name "My Tests")
endif()
if(NOT DEFINED CTEST_DASHBOARD_ROOT)
  get_filename_component(CTEST_DASHBOARD_ROOT "${CTEST_SCRIPT_DIRECTORY}/../${dashboard_root_name}" ABSOLUTE)
endif()

# Select the model (Nightly, Experimental, Continuous).
if(NOT DEFINED dashboard_model)
  set(dashboard_model Nightly)
endif()
if(NOT "${dashboard_model}" MATCHES "^(Nightly|Experimental|Continuous)$")
  message(FATAL_ERROR "dashboard_model must be Nightly, Experimental, or Continuous")
endif()

# Default to a Release build.
if(NOT DEFINED CTEST_CONFIGURATION_TYPE AND DEFINED CTEST_BUILD_CONFIGURATION)
  set(CTEST_CONFIGURATION_TYPE ${CTEST_BUILD_CONFIGURATION})
endif()

if(NOT DEFINED CTEST_CONFIGURATION_TYPE)
  set(CTEST_CONFIGURATION_TYPE Release)
endif()

# For SuperBuilds without subprojects, Dave Cole recommented not using launcher
set(CTEST_USE_LAUNCHERS 0)

# Configure testing.
if(NOT DEFINED CTEST_TEST_CTEST)
  set(CTEST_TEST_CTEST 1)
endif()
if(NOT CTEST_TEST_TIMEOUT)
  set(CTEST_TEST_TIMEOUT 1500)
endif()


# Select Git source to use.
if(NOT DEFINED dashboard_git_url)
  set(dashboard_git_url "https://github.com/SimpleITK/SimpleITK.git")
endif()
if(NOT DEFINED dashboard_git_branch)
# SimpleITK currently doesn't have a nightly-master
#  if("${dashboard_model}" STREQUAL "Nightly")
#    set(dashboard_git_branch nightly-master)
#  else()
    set(dashboard_git_branch master)
#  endif()
endif()
if(NOT DEFINED dashboard_git_crlf)
  if(UNIX)
    set(dashboard_git_crlf false)
  else(UNIX)
    set(dashboard_git_crlf true)
  endif(UNIX)
endif()

# Look for a GIT command-line client.
if(NOT DEFINED CTEST_GIT_COMMAND)
  find_program(CTEST_GIT_COMMAND NAMES git git.cmd)
endif()

if(NOT DEFINED CTEST_GIT_COMMAND)
  message(FATAL_ERROR "No Git Found.")
endif()

# Select a source directory name.
if(NOT DEFINED CTEST_SOURCE_DIRECTORY)
  if(DEFINED dashboard_source_name)
    set(CTEST_SOURCE_DIRECTORY ${CTEST_DASHBOARD_ROOT}/${dashboard_source_name})
  else()
    set(CTEST_SOURCE_DIRECTORY ${CTEST_DASHBOARD_ROOT}/SimpleITK)
  endif()
endif()

# set subdirectory used for configuration
if( NOT DEFINED dashboard_source_config_dir )
  set( dashboard_source_config_dir "SuperBuild")
endif()


# Select a build directory name.
if(NOT DEFINED CTEST_BINARY_DIRECTORY)
  if(DEFINED dashboard_binary_name)
    set(CTEST_BINARY_DIRECTORY ${CTEST_DASHBOARD_ROOT}/${dashboard_binary_name})
  else()
    set(CTEST_BINARY_DIRECTORY ${CTEST_SOURCE_DIRECTORY}-build)
  endif()
endif()

set(dashboard_build_dir "${CTEST_BINARY_DIRECTORY}")
if(dashboard_source_config_dir STREQUAL "SuperBuild")
  set(dashboard_build_dir "${dashboard_build_dir}/SimpleITK-build")
endif()


# Delete source tree if it is incompatible with current VCS.
if(EXISTS ${CTEST_SOURCE_DIRECTORY})
  if(NOT EXISTS "${CTEST_SOURCE_DIRECTORY}/.git")
    set(vcs_refresh "because it is not managed by git.")
  endif()
  if(vcs_refresh AND "${CTEST_SOURCE_DIRECTORY}" MATCHES "/(SimpleITK)[^/]*")
    message("Deleting source tree\n  ${CTEST_SOURCE_DIRECTORY}\n${vcs_refresh}")
    file(REMOVE_RECURSE "${CTEST_SOURCE_DIRECTORY}")
  endif()
endif()

# make sure build end in branch name
if( NOT CTEST_BUILD_NAME MATCHES "-${dashboard_git_branch}" )
  set(CTEST_BUILD_NAME "${CTEST_BUILD_NAME}-${dashboard_git_branch}")
endif()

# Support initial checkout if necessary.
if(NOT EXISTS "${CTEST_SOURCE_DIRECTORY}"
    AND NOT DEFINED CTEST_CHECKOUT_COMMAND)
  get_filename_component(_name "${CTEST_SOURCE_DIRECTORY}" NAME)
  execute_process(COMMAND ${CTEST_GIT_COMMAND} --version OUTPUT_VARIABLE output)
  string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+(\\.g[0-9a-f]+)?)?" GIT_VERSION "${output}")
  if(NOT "${GIT_VERSION}" VERSION_LESS "1.6.5")
    # Have "git clone -b <branch>" option.
    set(git_branch_new "-b ${dashboard_git_branch}")
    set(git_branch_old)
  else()
    # No "git clone -b <branch>" option.
    set(git_branch_new)
    set(git_branch_old "-b ${dashboard_git_branch} origin/${dashboard_git_branch}")
  endif()

    # Generate an initial checkout script.
    set(ctest_checkout_script ${CTEST_DASHBOARD_ROOT}/${_name}-init.cmake)
    file(WRITE ${ctest_checkout_script} "# git repo init script for ${_name}
execute_process(
  COMMAND \"${CTEST_GIT_COMMAND}\" clone -n ${git_branch_new} -- \"${dashboard_git_url}\"
          \"${CTEST_SOURCE_DIRECTORY}\"
  )
if(EXISTS \"${CTEST_SOURCE_DIRECTORY}/.git\")
  execute_process(
    COMMAND \"${CTEST_GIT_COMMAND}\" config core.autocrlf ${dashboard_git_crlf}
    WORKING_DIRECTORY \"${CTEST_SOURCE_DIRECTORY}\"
    )
  execute_process(
    COMMAND \"${CTEST_GIT_COMMAND}\" checkout ${git_branch_old}
    WORKING_DIRECTORY \"${CTEST_SOURCE_DIRECTORY}\"
    )
  execute_process(
    COMMAND \"${CTEST_GIT_COMMAND}\" submodule init
    WORKING_DIRECTORY \"${CTEST_SOURCE_DIRECTORY}\"
    )
  execute_process(
    COMMAND \"${CTEST_GIT_COMMAND}\" submodule update --
    WORKING_DIRECTORY \"${CTEST_SOURCE_DIRECTORY}\"
    )
endif()
")
  set(CTEST_CHECKOUT_COMMAND "\"${CMAKE_COMMAND}\" -P \"${ctest_checkout_script}\"")
  # CTest delayed initialization is broken, so we put the
  # CTestConfig.cmake info here.
  set(CTEST_NIGHTLY_START_TIME "01:00:00 UTC")
  set(CTEST_DROP_METHOD "https")
  set(CTEST_DROP_SITE "open.cdash.org")
  set(CTEST_DROP_LOCATION "submit.php?project=SimpleITK")
  set(CTEST_DROP_SITE_CDASH TRUE)
endif()

#-----------------------------------------------------------------------------

# Check for required variables.
foreach(req
    CTEST_CMAKE_GENERATOR
    CTEST_SITE
    CTEST_BUILD_NAME
    )
  if(NOT DEFINED ${req})
    message(FATAL_ERROR "The containing script must set ${req}")
  endif()
endforeach(req)

# Print summary information.
set(vars)
foreach(v
    CTEST_SITE
    CTEST_BUILD_NAME
    CTEST_SOURCE_DIRECTORY
    CTEST_BINARY_DIRECTORY
    CTEST_CMAKE_GENERATOR
    CTEST_BUILD_FLAGS
    CTEST_BUILD_CONFIGURATION
    CTEST_GIT_COMMAND
    CTEST_CHECKOUT_COMMAND
    CTEST_SCRIPT_DIRECTORY
    CTEST_USE_LAUNCHERS
    dashboard_source_config_dir
    dashboard_build_dir
    )
  set(vars "${vars}  ${v}=[${${v}}]\n")
endforeach(v)
message("Dashboard script configuration:\n${vars}\n")

# Avoid non-ascii characters in tool output.
set(ENV{LC_ALL} C)

# Helper macro to write the initial cache.
macro(write_cache)
  set(cache_build_type "")
  set(cache_make_program "")
  if(CTEST_CMAKE_GENERATOR MATCHES "Make")
    set(cache_build_type CMAKE_BUILD_TYPE:STRING=${CTEST_BUILD_CONFIGURATION})
    if(CMAKE_MAKE_PROGRAM)
      set(cache_make_program CMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM})
    endif()
  endif()
  file(WRITE ${CTEST_BINARY_DIRECTORY}/CMakeCache.txt "
SITE:STRING=${CTEST_SITE}
BUILDNAME:STRING=${CTEST_BUILD_NAME}
CTEST_USE_LAUNCHERS:BOOL=${CTEST_USE_LAUNCHERS}
DART_TESTING_TIMEOUT:STRING=${CTEST_TEST_TIMEOUT}
${cache_build_type}
${cache_make_program}
${dashboard_cache}
")
endmacro()

# Start with a fresh build tree.
if(NOT EXISTS "${CTEST_BINARY_DIRECTORY}")
  file(MAKE_DIRECTORY "${CTEST_BINARY_DIRECTORY}")
elseif(NOT "${CTEST_SOURCE_DIRECTORY}" STREQUAL "${CTEST_BINARY_DIRECTORY}"
    AND NOT dashboard_no_clean)
  message("Clearing build trees...")

  # rename to move it out of the way
  foreach(t "" 1 2 3 4 5)
    set(TEMP_BINARY_DIRECTORY "${CTEST_BINARY_DIRECTORY}.tmp${t}")
    if(EXISTS ${CTEST_BINARY_DIRECTORY} AND NOT EXISTS ${TEMP_BINARY_DIRECTORY})
      message("Moving old binary to ${TEMP_BINARY_DIRECTORY}...")
      file(RENAME "${CTEST_BINARY_DIRECTORY}" "${TEMP_BINARY_DIRECTORY}")
    endif()
  endforeach()

  # try try to delete older ones
  file(GLOB TEMP_BINARY_LIST "${CTEST_BINARY_DIRECTORY}.tmp*" )
  foreach(TEMP_BINARY_DIRECTORY ${CTEST_BINARY_DIRECTORY}.tmp ${TEMP_BINARY_LIST})
    if(EXISTS ${TEMP_BINARY_DIRECTORY})
      message("Removing ${TEMP_BINARY_DIRECTORY}...")
      ctest_empty_binary_directory(${TEMP_BINARY_DIRECTORY})
      file(REMOVE_RECURSE "${TEMP_BINARY_DIRECTORY}")
    endif()
  endforeach()
  ctest_empty_binary_directory(${CTEST_BINARY_DIRECTORY})
  message("Cleaned up!")
endif()

# set loop time to 0 if not Continuous
set(dashboard_continuous 0)
if("${dashboard_model}" STREQUAL "Continuous")
  set(dashboard_continuous 1)
endif()
if(NOT DEFINED dashboard_loop)
  if(dashboard_continuous)
    set(dashboard_loop 43200)
  else()
    set(dashboard_loop 0)
  endif()
endif()

if(COMMAND dashboard_hook_init)
  dashboard_hook_init()
endif()

set(dashboard_done 0)
while(NOT dashboard_done)
  if(dashboard_loop)
    set(START_TIME ${CTEST_ELAPSED_TIME})
  endif()
  set(ENV{HOME} "${dashboard_user_home}")

  # Start a new submission.
  if(COMMAND dashboard_hook_start)
    dashboard_hook_start()
  endif()
  if(dashboard_track)
    ctest_start(${dashboard_model} TRACK ${dashboard_track})
  else()
    ctest_start(${dashboard_model})
  endif()

  # Always build if the tree is fresh.
  set(dashboard_fresh 0)
  if(NOT EXISTS "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt"
     OR "${dashboard_do_cache}")
    set(dashboard_fresh 1)
    message("Writing initial dashboard cache...")
    write_cache()
  endif()

  # Look for updates.
  if(NOT dashboard_no_update)
    if (NOT CTEST_UPDATE_VERSION_ONLY )
      # make sure correct branch is checked out
      execute_process(COMMAND ${CTEST_GIT_COMMAND}  rev-parse --abbrev-ref HEAD
        OUTPUT_VARIABLE current_dashboard_git_branch
        OUTPUT_STRIP_TRAILING_WHITESPACE
        WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY})
      if(NOT current_dashboard_git_branch STREQUAL dashboard_git_branch)
        message("Checking out branch \"${dashboard_git_branch}\"...")
        execute_process(COMMAND ${CTEST_GIT_COMMAND} show-ref --verify --quiet "refs/heads/${dashboard_git_branch}"
          WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY}
          RESULT_VARIABLE ret)
        if (ret)
          # new checkout of branch
          execute_process(COMMAND ${CTEST_GIT_COMMAND} checkout -b ${dashboard_git_branch} origin/${dashboard_git_branch}
            WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY})
        else()
          execute_process(COMMAND ${CTEST_GIT_COMMAND} checkout ${dashboard_git_branch}
            WORKING_DIRECTORY ${CTEST_SOURCE_DIRECTORY})
        endif()
      endif()
    endif()

    ctest_update(RETURN_VALUE count)
  endif()
  if(NOT dashboard_no_submit AND NOT dashboard_no_parts)
    ctest_submit(PARTS Start Update)
  endif()
  set(CTEST_CHECKOUT_COMMAND) # checkout on first iteration only
  message("Found ${count} changed files")

  if(dashboard_fresh OR NOT dashboard_continuous OR count GREATER 0)
    ctest_configure( SOURCE "${CTEST_SOURCE_DIRECTORY}/${dashboard_source_config_dir}"
                     OPTIONS "${dashboard_configure_options}"
                     RETURN_VALUE configure_return
		      )
    if(NOT dashboard_no_submit AND NOT dashboard_no_parts)
      ctest_submit(PARTS Configure)
    endif()
    ctest_read_custom_files(${CTEST_BINARY_DIRECTORY})
    set(CTEST_PROJECT_NAME "SuperBuildSimpleITK")

    if(COMMAND dashboard_hook_build)
      dashboard_hook_build()
    endif()
    ctest_build( BUILD "${CTEST_BINARY_DIRECTORY}"
                 NUMBER_ERRORS build_number_errors
                 NUMBER_WARNINGS build_number_warnings)
    if(NOT dashboard_no_submit AND NOT dashboard_no_parts)
      ctest_submit(PARTS Build)
    endif()

    if(NOT dashboard_no_test)
      if(COMMAND dashboard_hook_test)
	dashboard_hook_test()
      endif()
      ctest_test( BUILD "${dashboard_build_dir}"
                  RETURN_VALUE test_return
                  EXCLUDE_LABEL UNSTABLE
                  ${CTEST_TEST_ARGS} )
      if(NOT dashboard_no_submit AND NOT dashboard_no_parts)
	ctest_submit(PARTS Test)
      endif()
    endif()

    if(dashboard_do_coverage)
      if(COMMAND dashboard_hook_coverage)
	dashboard_hook_coverage()
      endif()

      # HACK Unfortunately ctest_coverage ignores the BUILD argument, try to force it...
      file(READ ${CTEST_BINARY_DIRECTORY}/SimpleITK-build/CMakeFiles/TargetDirectories.txt build_coverage_dirs)
      file(APPEND "${CTEST_BINARY_DIRECTORY}/CMakeFiles/TargetDirectories.txt" "${build_coverage_dirs}")
      ctest_coverage( BUILD "${dashboard_build_dir}" )
      if(NOT dashboard_no_submit AND NOT dashboard_no_parts)
	ctest_submit(PARTS Coverage)
      endif()
    endif()
    if(dashboard_do_memcheck)
      if(COMMAND dashboard_hook_memcheck)
	dashboard_hook_memcheck()
      endif()
      ctest_memcheck( BUILD "${dashboard_build_dir}" )
      if(NOT dashboard_no_submit AND NOT dashboard_no_parts)
	ctest_submit(PARTS Build MemCheck)
      endif()

    endif()
    if(COMMAND dashboard_hook_submit)
      dashboard_hook_submit()
    endif()
    if(NOT dashboard_no_submit)
      # Send the main script as a note.
      list(APPEND CTEST_NOTES_FILES
	"${CTEST_SCRIPT_DIRECTORY}/${CTEST_SCRIPT_NAME}"
	"${CMAKE_CURRENT_LIST_FILE}"
       )
     if( NOT dashboard_no_parts )
       ctest_submit(PARTS Notes ExtraFiles Submit)
     else()
       ctest_submit()
     endif()
    endif()
    if(COMMAND dashboard_hook_end)
      dashboard_hook_end()
    endif()
  endif()

  if(dashboard_loop)
    # Delay until at least 5 minutes past START_TIME
    ctest_sleep(${START_TIME} 300 ${CTEST_ELAPSED_TIME})
    if(${CTEST_ELAPSED_TIME} GREATER ${dashboard_loop})
      set(dashboard_done 1)
    endif()
  else()
    # Not continuous, so we are done.
    set(dashboard_done 1)
  endif()
endwhile()
