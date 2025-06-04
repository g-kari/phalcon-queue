#!/bin/bash

# Security Scan Script for phalcon-queue
# This script performs basic security checks on the codebase

echo "🔒 Phalcon Queue Security Scanner"
echo "================================="
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track issues found
CRITICAL_ISSUES=0
HIGH_ISSUES=0
MEDIUM_ISSUES=0
LOW_ISSUES=0

echo "🔍 Scanning for security issues..."
echo ""

# 1. Check for hardcoded passwords/secrets
echo -e "${BLUE}[1/8]${NC} Checking for hardcoded credentials..."
if grep -r -n "password.*=.*['\"][a-zA-Z0-9]" --include="*.php" lib/ extra/ 2>/dev/null | grep -v "password.*ENV\|password.*getenv"; then
    echo -e "${RED}❌ CRITICAL: Hardcoded passwords found${NC}"
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
else
    echo -e "${GREEN}✅ No hardcoded passwords detected${NC}"
fi
echo ""

# 2. Check for unsafe unserialize usage
echo -e "${BLUE}[2/8]${NC} Checking for unsafe serialization..."
if grep -r -n "unserialize(" --include="*.php" lib/ extra/ 2>/dev/null | grep -v "allowed_classes"; then
    echo -e "${RED}❌ HIGH: Unsafe unserialize() usage found${NC}"
    HIGH_ISSUES=$((HIGH_ISSUES + 1))
else
    echo -e "${GREEN}✅ No unsafe unserialize usage detected${NC}"
fi
echo ""

# 3. Check for dangerous functions
echo -e "${BLUE}[3/8]${NC} Checking for dangerous functions..."
DANGEROUS_FUNCTIONS=("eval(" "exec(" "system(" "shell_exec(" "passthru(" "popen(" "proc_open(")
FOUND_DANGEROUS=false

for func in "${DANGEROUS_FUNCTIONS[@]}"; do
    if grep -r -n "$func" --include="*.php" lib/ extra/ 2>/dev/null; then
        echo -e "${RED}❌ HIGH: Dangerous function '$func' found${NC}"
        HIGH_ISSUES=$((HIGH_ISSUES + 1))
        FOUND_DANGEROUS=true
    fi
done

if [ "$FOUND_DANGEROUS" = false ]; then
    echo -e "${GREEN}✅ No dangerous functions detected${NC}"
fi
echo ""

# 4. Check for debug mode enabled
echo -e "${BLUE}[4/8]${NC} Checking for debug mode..."
if grep -r -n "'debug'.*=>.*true" --include="*.php" lib/ extra/ 2>/dev/null; then
    echo -e "${YELLOW}⚠️  MEDIUM: Debug mode enabled in code${NC}"
    MEDIUM_ISSUES=$((MEDIUM_ISSUES + 1))
else
    echo -e "${GREEN}✅ No hardcoded debug mode found${NC}"
fi
echo ""

# 5. Check for SQL injection patterns
echo -e "${BLUE}[5/8]${NC} Checking for potential SQL injection..."
if grep -r -n "query.*\\\$\|query.*\".*\\\$" --include="*.php" lib/ extra/ 2>/dev/null | grep -v ":"; then
    echo -e "${YELLOW}⚠️  MEDIUM: Potential SQL injection risk found${NC}"
    MEDIUM_ISSUES=$((MEDIUM_ISSUES + 1))
else
    echo -e "${GREEN}✅ SQL queries appear to use parameters${NC}"
fi
echo ""

# 6. Check for information disclosure in exceptions
echo -e "${BLUE}[6/8]${NC} Checking for information disclosure..."
if grep -r -n "getTrace()\|getFile()\|getLine()" --include="*.php" lib/ extra/ 2>/dev/null; then
    echo -e "${YELLOW}⚠️  MEDIUM: Exception details may leak information${NC}"
    MEDIUM_ISSUES=$((MEDIUM_ISSUES + 1))
else
    echo -e "${GREEN}✅ No exception information leakage detected${NC}"
fi
echo ""

# 7. Check for secure HTTP usage
echo -e "${BLUE}[7/8]${NC} Checking for HTTP security..."
if grep -r -n "http://" --include="*.php" lib/ extra/ 2>/dev/null; then
    echo -e "${YELLOW}⚠️  LOW: HTTP URLs found (consider HTTPS)${NC}"
    LOW_ISSUES=$((LOW_ISSUES + 1))
else
    echo -e "${GREEN}✅ No insecure HTTP URLs detected${NC}"
fi
echo ""

# 8. Check for file inclusion vulnerabilities
echo -e "${BLUE}[8/8]${NC} Checking for file inclusion risks..."
if grep -r -n "include.*\\\$\|require.*\\\$" --include="*.php" lib/ extra/ 2>/dev/null | grep -v "__DIR__"; then
    echo -e "${YELLOW}⚠️  MEDIUM: Dynamic file inclusion detected${NC}"
    MEDIUM_ISSUES=$((MEDIUM_ISSUES + 1))
else
    echo -e "${GREEN}✅ No dynamic file inclusion detected${NC}"
fi
echo ""

# Summary
echo "📊 Security Scan Summary"
echo "========================"
echo -e "Critical Issues: ${RED}${CRITICAL_ISSUES}${NC}"
echo -e "High Issues:     ${RED}${HIGH_ISSUES}${NC}"
echo -e "Medium Issues:   ${YELLOW}${MEDIUM_ISSUES}${NC}"
echo -e "Low Issues:      ${YELLOW}${LOW_ISSUES}${NC}"
echo ""

# Overall risk assessment
TOTAL_ISSUES=$((CRITICAL_ISSUES + HIGH_ISSUES + MEDIUM_ISSUES + LOW_ISSUES))

if [ $CRITICAL_ISSUES -gt 0 ] || [ $HIGH_ISSUES -gt 0 ]; then
    echo -e "${RED}🚨 OVERALL ASSESSMENT: HIGH RISK${NC}"
    echo "   Action required before production use"
    exit 1
elif [ $MEDIUM_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}⚠️  OVERALL ASSESSMENT: MEDIUM RISK${NC}"
    echo "   Consider addressing issues before production"
    exit 1
elif [ $LOW_ISSUES -gt 0 ]; then
    echo -e "${YELLOW}💡 OVERALL ASSESSMENT: LOW RISK${NC}"
    echo "   Minor improvements recommended"
    exit 0
else
    echo -e "${GREEN}✅ OVERALL ASSESSMENT: SECURE${NC}"
    echo "   No immediate security concerns detected"
    exit 0
fi