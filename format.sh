#!/bin/bash
swift-format --in-place --recursive ./Sources/ ./Tests/ && swift-format lint --recursive ./Sources/ ./Tests/
