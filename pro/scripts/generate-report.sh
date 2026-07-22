#!/usr/bin/env bash
# Inputs (env): LICENSED, USINGS_COUNT, NULLABLE_COUNT, BUILD_FAILED,
#               VULN_SCORE, VULN_FAILED, VULN_BENCHMARK, VULN_THRESHOLD,
#               SECRETS_COUNT
# Outputs: path

report_path="$RUNNER_TEMP/relgate-report.html"

{
  echo "<html><head><meta charset='utf-8'>"
  echo "<title>RelGate Report</title><style>"
  echo "body{font-family:sans-serif;margin:2rem}"
  echo "table{border-collapse:collapse}"
  echo "td,th{border:1px solid #ccc;padding:.4rem .8rem}"
  echo "</style></head><body>"
  echo "<h1>RelGate Report</h1>"
  echo "<h2>Free checks</h2>"
  echo "<table><tr><th>Category</th><th>Value</th></tr>"
  echo "<tr><td>Unused usings</td><td>$USINGS_COUNT</td></tr>"
  echo "<tr><td>Nullable warnings</td><td>$NULLABLE_COUNT</td></tr>"
  echo "<tr><td>Build failed</td><td>$BUILD_FAILED</td></tr>"
  echo "</table>"

  if [ "$LICENSED" = "true" ]; then
    status="OK"
    if [ "$VULN_FAILED" = "true" ]; then
      status="Below threshold"
    fi

    echo "<h2>Pro: Vulnerability Readiness</h2>"
    echo "<p>Score: $VULN_SCORE/100"
    echo "(threshold $VULN_THRESHOLD, benchmark reference $VULN_BENCHMARK)</p>"
    echo "<p>Status: $status</p>"

    echo "<h2>Pro: Secret scan</h2>"
    echo "<p>Potential secrets found: $SECRETS_COUNT</p>"
    if [ -s secret-hits.txt ]; then
      echo "<pre>"
      sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' secret-hits.txt
      echo "</pre>"
    fi
  else
    echo "<h2>Pro features</h2>"
    echo "<p>Not licensed — showing free-tier results only.</p>"
  fi

  year=$(date +%Y)
  echo "<hr>"
  echo "<p><small>© $year MigrateIQ &middot; <a href=\"https://github.com/MigrateIQ/relgate\">RelGate</a></small></p>"
  echo "</body></html>"
} > "$report_path"

echo "path=$report_path" >> "$GITHUB_OUTPUT"
