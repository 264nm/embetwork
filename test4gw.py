#!/usr/bin/env python
import os
import time
import json
import pycurl

# Path to results output file
TEMP_FILE = '/tmp/test4gw.temp'
# Slack webhook URL
SLACK_URL = 'https://hooks.slack.com/services/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Y9WXU6G'

def ping_host(host):
    """ Perform the actual pinging itself... return score 1 for exit code of 0
    Only works on unix\linux based OS.
    Params:
    count = 1
    timeout = 5s
    redirect output to /dev/null
    """
    response = os.system('ping -c 1 -t 5 ' + host + ' >/dev/null 2>&1')
    if response == 0:
        score = 1
    else:
        score = 0
    return score

def get_res():
    """ Define each hostname in dictionary as host:score pairs.
    Start with a score of 0 for each host. Ping each host 5 times every
    10 seconds. Each successful ping returns increments score by 1.
    Determine health as int between 0-5, rounding down to 3 if score is
    above 3 as otherwise alerting becomes to sensitive.
    """
    gateways = {
        'gwn1':0,
        'gwn2':0,
        'gws1':0,
        'gws2':0,
        }

    # Ping each host 5 times.
    for host,health in gateways.items():
        # number of times to ping
        freq_ping=5
        count = 0
        for i in range(0, freq_ping):
            x = ping_host(host)
            if x == 1:
                count += 1
                # sleep between ping attempts in seconds (10s for prod)
                time.sleep (10)
        # Round down a result to 3 if over 3 so not so sensitive
        if count > 2:
            count = 3
        # Return results as updated dictionary
        gw_health_res = {host:health + count for host,health in gateways.items()}
    return gw_health_res


def is_non_zero_file(fpath):
    """ Determine whether temporary file exists and isn't empty """
    return os.path.isfile(fpath) and os.path.getsize(fpath) > 0

def compare_results(results, results_prev):
    """ Compare obtained results from the previous script run result
    in order to alert when a gateway becomes unreachable or reachable
    """
    if results == results_prev:
        results_same = 'True'
    else:
        results_same = 'False'
    # Return as boolean
    return results_same

def dump_output(fname):
    """ Dump the results to a temp file as JSON to compare for next script run """
    results_JSON = json.dumps(results_dict, indent=4, skipkeys=True, sort_keys=True)
    f = open(TEMP_FILE, 'w')
    print >> f, results_JSON
    f.close()

def read_prev_output(fname):
    """ Read results of last script run to compare """
    with open(fname) as json_file:
        results_prev = json.load(json_file)
    return results_prev

def alert(payload):
    """ Send an alert to slack when results are different """
    post = json.dumps(payload)
    c = pycurl.Curl()
    c.setopt(pycurl.URL, '%s' % SLACK_URL)
    c.setopt(pycurl.HTTPHEADER, ['Accept: application/json', 'Content-Type: application/json'])
    c.setopt(pycurl.VERBOSE, 0)
    c.setopt(pycurl.POST, 1)
    c.setopt(pycurl.POSTFIELDS, post)
    c.perform()

def main():
    """ Main part of script logic. Get's the results, compares the results with
    previous, alert to slack when results are different, dump results to file
    for next time
    """
    # Get results
    global results_dict
    results_dict = get_res()
    # Convert dict to JSON
    results_JSON = json.dumps(results_dict, indent=4, skipkeys=True, sort_keys=True)

    # Check file containing previous output exists
    temp_not_empty = is_non_zero_file(TEMP_FILE)

    # If JSON file from previous script run is empty...
    if temp_not_empty == False:
        print (TEMP_FILE + ' is empty')
    else:
        print (TEMP_FILE + ' contains data')
        # Grab previous results from file
        results_dict_prev = read_prev_output(TEMP_FILE)
        compare_results_out = compare_results(results_dict, results_dict_prev)
        # If the results are different from previous time script ran, send alert
        if compare_results_out == 'False':
            print 'Results same as last script run %s' % compare_results_out
            # Build message body for alert
            msg = 'Gateway Status Alert (3 is good)..\nResults:\n%s' % results_dict
            headers = {'Content-Type':'application/json'}
            payload = {'text': msg}
            # Send alert to slack
            alert(payload)
        else:
            print 'Results same as last script run: %s' % compare_results_out

    # Dump results from this script run to temp file in order to compare next time
    dump_output(TEMP_FILE)
    pass

if __name__ == "__main__":
    main()
