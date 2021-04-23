class CollectorResult:
    collector = None
    source = None
    output = None
    error = None

    def __init__(self, collector, source):
        self.collector = collector
        self.source = source    