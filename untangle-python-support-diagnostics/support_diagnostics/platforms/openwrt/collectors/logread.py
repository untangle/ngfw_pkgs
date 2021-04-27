import subprocess

from support_diagnostics import Collector,CollectorResult

class LogreadCollector(Collector):
    id = "os_logread"

    """
    Get log contents
    """
    def collect(self):
        results = []

        result = CollectorResult(self, "logread")
        result.output = []
        proc = subprocess.Popen(['logread'], stdout=subprocess.PIPE)
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            result.output.append(line.decode("ascii").rstrip())

        # result.output.append("Thu Dec 10 08:05:24 2020 daemon.info packetd[2454]: WARN              reports: Error calling client.Do: Post https://database.untangle.com/v1/put?source=d2402047-87c9-44d8-a894-b13584e4f941&type=db&queueName=mfw_events: net/http: request canceled (Client.Timeout exceeded while awaiting headers)")

        results.append(result)

        return results