#!/usr/bin/env bash
# Comprehensive Test Suite for Llama3 Kubernetes Deployment
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="llama3-multi-adapter"
LOG_DIR="./test-results-$(date +%Y%m%d-%H%M%S)"
RESULTS_FILE="${LOG_DIR}/test-results.json"
SUMMARY_FILE="${LOG_DIR}/summary.md"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Create log directory
mkdir -p "$LOG_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOG_DIR}/test.log"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*" | tee -a "${LOG_DIR}/test.log"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*" | tee -a "${LOG_DIR}/test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOG_DIR}/test.log"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*" | tee -a "${LOG_DIR}/test.log"
}

# Test result tracking
record_test() {
    local test_name="$1"
    local status="$2"
    local details="${3:-}"
    local duration="${4:-0}"
    
    ((TOTAL_TESTS++))
    
    case "$status" in
        "PASS") ((PASSED_TESTS++)) ;;
        "FAIL") ((FAILED_TESTS++)) ;;
        "SKIP") ((SKIPPED_TESTS++)) ;;
    esac
    
    # Append to JSON results
    cat >> "$RESULTS_FILE" << EOF
{
  "test": "$test_name",
  "status": "$status",
  "details": "$details",
  "duration_seconds": $duration,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
},
EOF
}

# Initialize results file
cat > "$RESULTS_FILE" << 'EOF'
{
  "test_suite": "Llama3 Kubernetes Deployment Tests",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "namespace": "llama3-multi-adapter",
  "tests": [
EOF

echo "============================================="
echo "  Llama3 Kubernetes Deployment Test Suite"
echo "============================================="
echo ""

# =============================================================================
# TEST 1: Namespace Verification
# =============================================================================
test_namespace_exists() {
    log_info "Test 1: Verifying namespace exists..."
    local start_time=$(date +%s)
    
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log_success "Namespace '$NAMESPACE' exists"
        local end_time=$(date +%s)
        record_test "namespace_exists" "PASS" "Namespace $NAMESPACE found" $((end_time - start_time))
    else
        log_error "Namespace '$NAMESPACE' does not exist"
        local end_time=$(date +%s)
        record_test "namespace_exists" "FAIL" "Namespace $NAMESPACE not found" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 2: Pod Status Verification
# =============================================================================
test_pod_status() {
    log_info "Test 2: Checking pod status..."
    local start_time=$(date +%s)
    
    local pods_output=$(kubectl get pods -n "$NAMESPACE" -o json)
    local total_pods=$(echo "$pods_output" | jq -r '.items | length')
    local running_pods=$(echo "$pods_output" | jq -r '[.items[] | select(.status.phase == "Running")] | length')
    local terminating_pods=$(echo "$pods_output" | jq -r '[.items[] | select(.metadata.deletionTimestamp != null)] | length')
    
    log_info "  Total pods: $total_pods"
    log_info "  Running pods: $running_pods"
    log_info "  Terminating pods: $terminating_pods"
    
    kubectl get pods -n "$NAMESPACE" -o wide | tee "${LOG_DIR}/pod-status.txt"
    
    if [[ $running_pods -gt 0 ]]; then
        log_success "Found $running_pods running pods"
        local end_time=$(date +%s)
        record_test "pod_status" "PASS" "$running_pods running pods found" $((end_time - start_time))
    else
        log_error "No running pods found"
        local end_time=$(date +%s)
        record_test "pod_status" "FAIL" "No running pods" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 3: Service Discovery
# =============================================================================
test_service_discovery() {
    log_info "Test 3: Verifying services..."
    local start_time=$(date +%s)
    
    local services=$(kubectl get svc -n "$NAMESPACE" -o json)
    local service_count=$(echo "$services" | jq -r '.items | length')
    
    kubectl get svc -n "$NAMESPACE" -o wide | tee "${LOG_DIR}/service-list.txt"
    
    log_info "  Found $service_count services"
    
    local key_services=(
        "hybrid-inference-proxy"
        "ollama-simple-fast"
        "qdrant-api"
    )
    
    local all_found=true
    for svc in "${key_services[@]}"; do
        if echo "$services" | jq -e ".items[] | select(.metadata.name == \"$svc\")" &>/dev/null; then
            log_success "  Service '$svc' found"
        else
            log_warning "  Service '$svc' not found"
            all_found=false
        fi
    done
    
    local end_time=$(date +%s)
    if $all_found; then
        record_test "service_discovery" "PASS" "All key services found" $((end_time - start_time))
    else
        record_test "service_discovery" "FAIL" "Some services missing" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 4: Endpoint Connectivity - Ollama Simple
# =============================================================================
test_ollama_simple_connectivity() {
    log_info "Test 4: Testing Ollama simple-fast endpoint..."
    local start_time=$(date +%s)
    
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app=ollama-simple-fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log_skip "Ollama simple-fast pod not found"
        local end_time=$(date +%s)
        record_test "ollama_simple_connectivity" "SKIP" "Pod not found" $((end_time - start_time))
        return
    fi
    
    log_info "  Testing connectivity to pod: $pod"
    
    # Test health endpoint
    if kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf http://localhost:11434/ &>/dev/null; then
        log_success "  Ollama health check passed"
        
        # Test models endpoint
        local models=$(kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf http://localhost:11434/api/tags 2>/dev/null)
        echo "$models" > "${LOG_DIR}/ollama-models.json"
        
        local model_count=$(echo "$models" | jq -r '.models | length' 2>/dev/null || echo "0")
        log_info "  Available models: $model_count"
        
        local end_time=$(date +%s)
        record_test "ollama_simple_connectivity" "PASS" "Ollama responding, $model_count models" $((end_time - start_time))
    else
        log_error "  Ollama health check failed"
        local end_time=$(date +%s)
        record_test "ollama_simple_connectivity" "FAIL" "Health check failed" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 5: Endpoint Connectivity - Hybrid Proxy
# =============================================================================
test_hybrid_proxy_connectivity() {
    log_info "Test 5: Testing hybrid inference proxy..."
    local start_time=$(date +%s)
    
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app=hybrid-inference-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log_skip "Hybrid proxy pod not found"
        local end_time=$(date +%s)
        record_test "hybrid_proxy_connectivity" "SKIP" "Pod not found" $((end_time - start_time))
        return
    fi
    
    log_info "  Testing connectivity to pod: $pod"
    
    # Test health endpoint
    if kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf http://localhost:8080/health &>/dev/null; then
        log_success "  Hybrid proxy health check passed"
        local end_time=$(date +%s)
        record_test "hybrid_proxy_connectivity" "PASS" "Proxy responding" $((end_time - start_time))
    else
        log_error "  Hybrid proxy health check failed"
        local end_time=$(date +%s)
        record_test "hybrid_proxy_connectivity" "FAIL" "Health check failed" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 6: Qdrant Vector Database
# =============================================================================
test_qdrant_connectivity() {
    log_info "Test 6: Testing Qdrant vector database..."
    local start_time=$(date +%s)
    
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app=qdrant -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log_skip "Qdrant pod not found"
        local end_time=$(date +%s)
        record_test "qdrant_connectivity" "SKIP" "Pod not found" $((end_time - start_time))
        return
    fi
    
    log_info "  Testing connectivity to pod: $pod"
    
    # Test Qdrant API
    if kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf http://localhost:6333/collections &>/dev/null; then
        log_success "  Qdrant API responding"
        
        # Get collections
        local collections=$(kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf http://localhost:6333/collections 2>/dev/null)
        echo "$collections" > "${LOG_DIR}/qdrant-collections.json"
        
        local end_time=$(date +%s)
        record_test "qdrant_connectivity" "PASS" "Qdrant responding" $((end_time - start_time))
    else
        log_error "  Qdrant API check failed"
        local end_time=$(date +%s)
        record_test "qdrant_connectivity" "FAIL" "API check failed" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 7: Model Inference - Simple Text Generation
# =============================================================================
test_simple_inference() {
    log_info "Test 7: Testing simple text inference..."
    local start_time=$(date +%s)
    
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app=ollama-simple-fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log_skip "Ollama pod not found for inference test"
        local end_time=$(date +%s)
        record_test "simple_inference" "SKIP" "Pod not found" $((end_time - start_time))
        return
    fi
    
    log_info "  Sending test prompt to Ollama..."
    
    # Create test payload
    local test_prompt='{"model": "llama3.2:3b", "prompt": "What is Kubernetes? Answer in one sentence.", "stream": false}'
    
    # Execute inference
    local response=$(kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "$test_prompt" 2>/dev/null || echo '{"error": true}')
    
    echo "$response" > "${LOG_DIR}/simple-inference-response.json"
    
    if echo "$response" | jq -e '.response' &>/dev/null; then
        local answer=$(echo "$response" | jq -r '.response' | head -c 200)
        log_success "  Inference successful"
        log_info "  Response preview: ${answer}..."
        
        local end_time=$(date +%s)
        record_test "simple_inference" "PASS" "Inference completed successfully" $((end_time - start_time))
    else
        log_error "  Inference failed or returned error"
        local end_time=$(date +%s)
        record_test "simple_inference" "FAIL" "Inference error" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 8: Resource Utilization
# =============================================================================
test_resource_utilization() {
    log_info "Test 8: Checking resource utilization..."
    local start_time=$(date +%s)
    
    # Get pod metrics (requires metrics-server)
    if kubectl top pods -n "$NAMESPACE" &>/dev/null; then
        kubectl top pods -n "$NAMESPACE" | tee "${LOG_DIR}/pod-resources.txt"
        log_success "  Resource metrics collected"
        local end_time=$(date +%s)
        record_test "resource_utilization" "PASS" "Metrics collected" $((end_time - start_time))
    else
        log_warning "  Metrics server not available or no metrics"
        local end_time=$(date +%s)
        record_test "resource_utilization" "SKIP" "Metrics server unavailable" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 9: Pod Logs Verification
# =============================================================================
test_pod_logs() {
    log_info "Test 9: Collecting pod logs..."
    local start_time=$(date +%s)
    
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    mkdir -p "${LOG_DIR}/pod-logs"
    
    local log_count=0
    for pod in $pods; do
        local status=$(kubectl get pod -n "$NAMESPACE" "$pod" -o jsonpath='{.status.phase}')
        
        if [[ "$status" != "Terminating" ]]; then
            log_info "  Collecting logs from: $pod"
            kubectl logs -n "$NAMESPACE" "$pod" --tail=100 > "${LOG_DIR}/pod-logs/${pod}.log" 2>&1 || true
            ((log_count++))
        fi
    done
    
    log_success "  Collected logs from $log_count pods"
    local end_time=$(date +%s)
    record_test "pod_logs" "PASS" "Logs collected from $log_count pods" $((end_time - start_time))
}

# =============================================================================
# TEST 10: Configuration Validation
# =============================================================================
test_configuration_validation() {
    log_info "Test 10: Validating configurations..."
    local start_time=$(date +%s)
    
    # Check ConfigMaps
    local configmaps=$(kubectl get configmaps -n "$NAMESPACE" -o json)
    local cm_count=$(echo "$configmaps" | jq -r '.items | length')
    
    # Check Secrets
    local secrets=$(kubectl get secrets -n "$NAMESPACE" -o json)
    local secret_count=$(echo "$secrets" | jq -r '.items | length')
    
    # Check PVCs
    local pvcs=$(kubectl get pvc -n "$NAMESPACE" -o json)
    local pvc_count=$(echo "$pvcs" | jq -r '.items | length')
    
    log_info "  ConfigMaps: $cm_count"
    log_info "  Secrets: $secret_count"
    log_info "  PVCs: $pvc_count"
    
    kubectl get configmaps,secrets,pvc -n "$NAMESPACE" > "${LOG_DIR}/configurations.txt" 2>&1
    
    log_success "  Configuration inventory completed"
    local end_time=$(date +%s)
    record_test "configuration_validation" "PASS" "CM: $cm_count, Secrets: $secret_count, PVC: $pvc_count" $((end_time - start_time))
}

# =============================================================================
# TEST 11: Network Policies (if any)
# =============================================================================
test_network_policies() {
    log_info "Test 11: Checking network policies..."
    local start_time=$(date +%s)
    
    local netpols=$(kubectl get networkpolicies -n "$NAMESPACE" -o json)
    local netpol_count=$(echo "$netpols" | jq -r '.items | length')
    
    if [[ $netpol_count -gt 0 ]]; then
        kubectl get networkpolicies -n "$NAMESPACE" -o yaml > "${LOG_DIR}/network-policies.yaml"
        log_info "  Found $netpol_count network policies"
        local end_time=$(date +%s)
        record_test "network_policies" "PASS" "$netpol_count policies found" $((end_time - start_time))
    else
        log_info "  No network policies found"
        local end_time=$(date +%s)
        record_test "network_policies" "SKIP" "No policies configured" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 12: Event Log Analysis
# =============================================================================
test_event_analysis() {
    log_info "Test 12: Analyzing recent events..."
    local start_time=$(date +%s)
    
    local events=$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' -o json)
    echo "$events" | jq '.' > "${LOG_DIR}/events.json"
    
    local warning_count=$(echo "$events" | jq -r '[.items[] | select(.type == "Warning")] | length')
    local error_count=$(echo "$events" | jq -r '[.items[] | select(.type == "Error")] | length')
    
    log_info "  Warning events: $warning_count"
    log_info "  Error events: $error_count"
    
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -20 | tee "${LOG_DIR}/recent-events.txt"
    
    local end_time=$(date +%s)
    if [[ $error_count -eq 0 ]]; then
        log_success "  No error events found"
        record_test "event_analysis" "PASS" "Warnings: $warning_count, Errors: $error_count" $((end_time - start_time))
    else
        log_warning "  Found $error_count error events"
        record_test "event_analysis" "FAIL" "Warnings: $warning_count, Errors: $error_count" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 13: Performance Benchmark - Latency
# =============================================================================
test_inference_latency() {
    log_info "Test 13: Testing inference latency..."
    local start_time=$(date +%s)
    
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app=ollama-simple-fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log_skip "Ollama pod not found for latency test"
        local end_time=$(date +%s)
        record_test "inference_latency" "SKIP" "Pod not found" $((end_time - start_time))
        return
    fi
    
    log_info "  Running 5 inference requests to measure latency..."
    
    local total_time=0
    local success_count=0
    
    for i in {1..5}; do
        local req_start=$(date +%s%N)
        
        if kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf -X POST http://localhost:11434/api/generate \
            -H "Content-Type: application/json" \
            -d '{"model": "llama3.2:3b", "prompt": "Hello", "stream": false}' &>/dev/null; then
            
            local req_end=$(date +%s%N)
            local duration=$(( (req_end - req_start) / 1000000 )) # Convert to milliseconds
            total_time=$((total_time + duration))
            ((success_count++))
            log_info "  Request $i: ${duration}ms"
        else
            log_warning "  Request $i: failed"
        fi
    done
    
    if [[ $success_count -gt 0 ]]; then
        local avg_latency=$((total_time / success_count))
        log_success "  Average latency: ${avg_latency}ms ($success_count/5 successful)"
        local end_time=$(date +%s)
        record_test "inference_latency" "PASS" "Avg: ${avg_latency}ms, Success: $success_count/5" $((end_time - start_time))
    else
        log_error "  All latency tests failed"
        local end_time=$(date +%s)
        record_test "inference_latency" "FAIL" "All requests failed" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 14: Concurrent Request Handling
# =============================================================================
test_concurrent_requests() {
    log_info "Test 14: Testing concurrent request handling..."
    local start_time=$(date +%s)
    
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app=ollama-simple-fast -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [[ -z "$pod" ]]; then
        log_skip "Ollama pod not found for concurrency test"
        local end_time=$(date +%s)
        record_test "concurrent_requests" "SKIP" "Pod not found" $((end_time - start_time))
        return
    fi
    
    log_info "  Launching 3 concurrent requests..."
    
    # Launch concurrent requests in background
    local pids=()
    for i in {1..3}; do
        (
            kubectl exec -n "$NAMESPACE" "$pod" -- curl -sf -X POST http://localhost:11434/api/generate \
                -H "Content-Type: application/json" \
                -d "{\"model\": \"llama3.2:3b\", \"prompt\": \"Test $i\", \"stream\": false}" \
                &>/dev/null && echo "success" || echo "failure"
        ) > "${LOG_DIR}/concurrent-req-${i}.txt" &
        pids+=($!)
    done
    
    # Wait for all requests
    local success_count=0
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Count successes
    success_count=$(grep -l "success" "${LOG_DIR}"/concurrent-req-*.txt 2>/dev/null | wc -l)
    
    log_info "  Concurrent requests completed: $success_count/3 successful"
    
    local end_time=$(date +%s)
    if [[ $success_count -ge 2 ]]; then
        log_success "  Concurrent request handling working"
        record_test "concurrent_requests" "PASS" "$success_count/3 successful" $((end_time - start_time))
    else
        log_warning "  Only $success_count/3 concurrent requests succeeded"
        record_test "concurrent_requests" "FAIL" "Only $success_count/3 successful" $((end_time - start_time))
    fi
}

# =============================================================================
# TEST 15: Deployment Manifest Validation
# =============================================================================
test_manifest_validation() {
    log_info "Test 15: Validating deployment manifests..."
    local start_time=$(date +%s)
    
    local deployments=$(kubectl get deployments -n "$NAMESPACE" -o json)
    local deploy_count=$(echo "$deployments" | jq -r '.items | length')
    
    log_info "  Found $deploy_count deployments"
    
    # Check each deployment for proper configuration
    local validation_passed=true
    echo "$deployments" | jq -r '.items[].metadata.name' | while read -r deploy; do
        local replicas=$(kubectl get deployment -n "$NAMESPACE" "$deploy" -o jsonpath='{.spec.replicas}')
        local ready=$(kubectl get deployment -n "$NAMESPACE" "$deploy" -o jsonpath='{.status.readyReplicas}')
        
        log_info "  Deployment '$deploy': $ready/$replicas ready"
        
        if [[ "${ready:-0}" -lt "${replicas:-1}" ]]; then
            validation_passed=false
        fi
    done
    
    kubectl get deployments -n "$NAMESPACE" -o wide > "${LOG_DIR}/deployments.txt"
    
    local end_time=$(date +%s)
    if $validation_passed; then
        log_success "  All deployments properly configured"
        record_test "manifest_validation" "PASS" "$deploy_count deployments validated" $((end_time - start_time))
    else
        log_warning "  Some deployments not fully ready"
        record_test "manifest_validation" "FAIL" "Some deployments not ready" $((end_time - start_time))
    fi
}

# =============================================================================
# Run All Tests
# =============================================================================
main() {
    log_info "Starting comprehensive test suite..."
    log_info "Results will be saved to: $LOG_DIR"
    echo ""
    
    test_namespace_exists
    test_pod_status
    test_service_discovery
    test_ollama_simple_connectivity
    test_hybrid_proxy_connectivity
    test_qdrant_connectivity
    test_simple_inference
    test_resource_utilization
    test_pod_logs
    test_configuration_validation
    test_network_policies
    test_event_analysis
    test_inference_latency
    test_concurrent_requests
    test_manifest_validation
    
    # Finalize results JSON
    sed -i '$ s/,$//' "$RESULTS_FILE"  # Remove trailing comma
    cat >> "$RESULTS_FILE" << EOF
  ],
  "completed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "total": $TOTAL_TESTS,
    "passed": $PASSED_TESTS,
    "failed": $FAILED_TESTS,
    "skipped": $SKIPPED_TESTS
  }
}
EOF
    
    # Generate summary report
    generate_summary_report
    
    # Display summary
    echo ""
    echo "============================================="
    echo "  Test Summary"
    echo "============================================="
    echo "Total Tests:   $TOTAL_TESTS"
    echo "Passed:        $PASSED_TESTS"
    echo "Failed:        $FAILED_TESTS"
    echo "Skipped:       $SKIPPED_TESTS"
    echo ""
    echo "Results saved to: $LOG_DIR"
    echo "Summary report:   $SUMMARY_FILE"
    echo "JSON results:     $RESULTS_FILE"
    echo "============================================="
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Generate markdown summary report
generate_summary_report() {
    cat > "$SUMMARY_FILE" << EOF
# Llama3 Kubernetes Deployment Test Report

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Namespace:** $NAMESPACE  
**Results Directory:** $LOG_DIR

## Summary

| Metric | Count |
|--------|-------|
| Total Tests | $TOTAL_TESTS |
| Passed | $PASSED_TESTS |
| Failed | $FAILED_TESTS |
| Skipped | $SKIPPED_TESTS |

## Test Results

EOF
    
    # Parse JSON results and add to summary
    jq -r '.tests[] | "### \(.test)\n- **Status:** \(.status)\n- **Details:** \(.details)\n- **Duration:** \(.duration_seconds)s\n"' "$RESULTS_FILE" >> "$SUMMARY_FILE" 2>/dev/null || true
    
    cat >> "$SUMMARY_FILE" << EOF

## Artifacts

- Pod status: \`pod-status.txt\`
- Service list: \`service-list.txt\`
- Pod logs: \`pod-logs/\`
- Events: \`events.json\`
- Configurations: \`configurations.txt\`
- Inference responses: \`*-inference-response.json\`

## Recommendations

EOF
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        cat >> "$SUMMARY_FILE" << EOF
⚠️ **Action Required:** $FAILED_TESTS test(s) failed. Review the detailed logs and address failures.

EOF
    else
        cat >> "$SUMMARY_FILE" << EOF
✅ All tests passed successfully. System is operating normally.

EOF
    fi
    
    cat >> "$SUMMARY_FILE" << EOF
## Next Steps

1. Review detailed logs in \`$LOG_DIR\`
2. Check pod logs for any errors: \`$LOG_DIR/pod-logs/\`
3. Analyze recent events: \`$LOG_DIR/events.json\`
4. Monitor resource utilization: \`$LOG_DIR/pod-resources.txt\`

---
Generated by Llama3 Kubernetes Test Suite
EOF
}

# Execute main function
main "$@"
