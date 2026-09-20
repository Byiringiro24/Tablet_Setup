# EcaAfrica System - Quick Reference Guide
**Status:** ✅ PRODUCTION READY  
**Last Updated:** September 19, 2026

---

## 🚀 Quick Start Commands

### Backend
```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Run development server
npm run dev

# Start production (PM2)
pm2 start dist/index.js --name ecareafrica-api

# View logs
pm2 logs ecareafrica-api
```

### Frontend
```bash
# Install dependencies
npm install

# Build for production
npm run build

# Run dev server
npm run dev

# Preview build
npm run preview
```

### Database
```bash
# Run migrations
npx prisma migrate deploy

# View database
npx prisma studio

# Backup
pg_dump ecareafrica > backup_$(date +%s).dump

# Restore
psql ecareafrica < backup_timestamp.dump
```

---

## 📊 Critical Metrics Dashboard

### Health Check URLs
- **Backend Health:** `GET /api/v1/health`
- **Database:** `SELECT 1;` via `psql`
- **Frontend:** Check `https://yourdomain.com`

### Expected Response Times
- **API Endpoints:** <200ms (p95)
- **Attendance Query:** <500ms (1M records)
- **Student List:** <150ms (10K students)
- **Device Status:** <100ms

### Alert Thresholds
| Metric | Warning | Critical |
|--------|---------|----------|
| API Latency | >300ms | >1000ms |
| Error Rate | >1% | >5% |
| DB Connections | >80% | >95% |
| Disk Usage | >80% | >95% |

---

## 🔐 Security Quick Check

### Must Verify Before Production
- [x] HTTPS enabled
- [x] JWT secret configured (strong random string)
- [x] Database password strong (20+ chars)
- [x] CORS origins configured correctly
- [x] Rate limiting enabled
- [x] Audit logging active
- [x] Backup encryption enabled

### Environment Variables
```bash
# Backend (.env)
DATABASE_URL=postgresql://user:pass@host:5432/ecareafrica
JWT_SECRET=your-long-random-secret-here
ADMIN_EMAIL=admin@school.com
NODE_ENV=production
PORT=3000
CORS_ORIGIN=https://yourdomain.com

# Frontend (.env)
VITE_API_URL=https://api.yourdomain.com
VITE_APP_NAME=EcaAfrica
```

---

## 📱 Device Management Commands

### List All Devices
```bash
curl -X GET https://api.yourdomain.com/api/v1/devices \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Register New Device
```bash
curl -X POST https://api.yourdomain.com/api/v1/devices \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_uid": "DEV-001",
    "name": "Main Gate",
    "type": "GATE",
    "mode": "ATTENDANCE"
  }'
```

### Check Device Status
```bash
curl -X GET https://api.yourdomain.com/api/v1/devices/{id}/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 👨‍🎓 Student Management

### Import Students (Bulk)
```bash
curl -X POST https://api.yourdomain.com/api/v1/students/import \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"students": [...]} | head -100' # Import format
```

### Get Student by ID
```bash
curl -X GET https://api.yourdomain.com/api/v1/students/{id} \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### List Students by School
```bash
curl -X GET https://api.yourdomain.com/api/v1/students?page=1&limit=50 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 📋 Attendance Queries

### Get Device Logs (Today)
```bash
curl -X GET 'https://api.yourdomain.com/api/v1/attendance/records/device-logs/today' \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Get Attendance Statistics
```bash
curl -X GET 'https://api.yourdomain.com/api/v1/attendance/records/device-logs/stats?startDate=2026-09-01&endDate=2026-09-30' \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Export Attendance (CSV)
```bash
# Use the attendance export endpoint
curl -X GET 'https://api.yourdomain.com/api/v1/attendance/export' \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" > attendance.csv
```

---

## 🛠️ Troubleshooting

### Backend Won't Start
```bash
# Check logs
pm2 logs ecareafrica-api --lines 100

# Verify database connection
psql -U postgres -h localhost -d ecareafrica -c "SELECT 1;"

# Check port availability
netstat -ano | findstr :3000  # Windows
lsof -i :3000  # Linux/Mac
```

### Database Connection Issues
```bash
# Test connection
psql postgresql://user:pass@host:5432/ecareafrica

# Verify pool
SELECT count(*) FROM pg_stat_activity;

# Kill idle connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'ecareafrica' AND state = 'idle';
```

### API Returns 500 Errors
```bash
# 1. Check backend logs
pm2 logs ecareafrica-api

# 2. Verify environment variables
env | grep DATABASE_URL
env | grep JWT_SECRET

# 3. Check database for schema issues
npx prisma introspect

# 4. Run migrations if needed
npx prisma migrate deploy
```

### Device Can't Connect
```bash
# 1. Check device status
curl -X GET https://api.yourdomain.com/api/v1/devices/{id}/status

# 2. Verify network connectivity
ping device-ip-address

# 3. Check firewall rules
# Device must reach: api.yourdomain.com:443

# 4. Review device logs
# SSH into device and check: /var/log/ecareafrica-tablet.log
```

---

## 📈 Scaling Guidelines

### When to Scale
| Metric | Value | Action |
|--------|-------|--------|
| API Latency | >500ms | Add more backend instances |
| DB Connections | >90% | Increase connection pool |
| Disk Usage | >80% | Archive old attendance logs |
| Error Rate | >2% | Review logs, scale if needed |

### Horizontal Scaling
```bash
# Add more backend instances
pm2 start dist/index.js --name ecareafrica-api --instances 4

# Load balance with nginx/haproxy
# Round-robin across multiple backend instances
```

### Vertical Scaling
```bash
# Increase server resources
# - RAM: 4GB → 8GB → 16GB
# - CPU: Add cores as needed
# - Database: Add SSD storage

# Adjust connection pool
DATABASE_URL="postgresql://...?pool_size=500"
```

---

## 🔄 Database Maintenance

### Daily Tasks (Automated)
```bash
# Backup
pg_dump ecareafrica | gzip > backup_$(date +%s).dump.gz

# Verify backup
gunzip -c backup_*.dump.gz | psql ecareafrica
```

### Weekly Tasks
```bash
# Vacuum and analyze
VACUUM ANALYZE;

# Check for missing indexes
SELECT * FROM pg_stat_user_indexes ORDER BY idx_scan;

# Monitor table size
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Monthly Tasks
```bash
# Archive old attendance logs (>6 months)
DELETE FROM attendance_logs 
WHERE timestamp < CURRENT_DATE - INTERVAL '6 months';

# Reindex
REINDEX DATABASE ecareafrica;

# Generate report
SELECT COUNT(*) as total_students FROM students WHERE deleted_at IS NULL;
SELECT COUNT(*) as total_logs FROM attendance_logs;
```

---

## 🎯 Performance Optimization Checklist

### Database
- [x] Indexes on: school_id, device_user_id, student_id
- [x] Connection pooling: 100-500 connections
- [x] Query timeout: 30 seconds
- [ ] Add read replicas (for analytics)
- [ ] Enable query caching (Redis)

### Application
- [x] Gzip compression enabled
- [x] HTTP caching headers configured
- [x] Rate limiting enabled
- [ ] Implement CDN for frontend
- [ ] Add APM monitoring (New Relic/DataDog)

### Infrastructure
- [x] HTTPS/TLS enabled
- [x] Firewall rules configured
- [ ] Auto-scaling based on metrics
- [ ] Multi-region deployment
- [ ] Disaster recovery setup

---

## 📞 Support Matrix

| Issue | Solution | Time to Fix |
|-------|----------|------------|
| API 500 error | Check logs, restart | 5-10 min |
| Device offline | Check network, reconnect | 2-5 min |
| Slow queries | Check indexes, archive old data | 15-30 min |
| Database full | Archive logs, increase disk | 30-60 min |
| Connection pool exhausted | Increase pool size, restart | 10-15 min |

---

## 🚨 Emergency Procedures

### Database Emergency
```bash
# 1. Backup immediately
pg_dump ecareafrica > emergency_backup.dump

# 2. Restart database
sudo systemctl restart postgresql

# 3. Check integrity
PRAGMA integrity_check;  # Or PostgreSQL equivalent
```

### API Server Down
```bash
# 1. Check service status
pm2 status

# 2. Restart service
pm2 restart ecareafrica-api

# 3. If needed, restart all
pm2 restart all

# 4. Verify health
curl http://localhost:3000/api/v1/health
```

### Data Corruption
```bash
# 1. Stop application
pm2 stop ecareafrica-api

# 2. Restore from backup
psql ecareafrica < backup_timestamp.dump

# 3. Verify data
SELECT COUNT(*) FROM students;

# 4. Restart application
pm2 start ecareafrica-api
```

---

## 📚 Useful Links

- **API Documentation:** `/docs/swagger.yaml`
- **Database Schema:** Run `npx prisma studio`
- **Error Codes:** See `src/middleware/errorHandler.ts`
- **Logs:** `pm2 logs ecareafrica-api`
- **Monitoring:** Check `localhost:9090` (if Prometheus installed)

---

## ✅ Deployment Verification

After deployment, verify:

```bash
# 1. Frontend loads
curl -I https://yourdomain.com

# 2. API is responsive
curl https://api.yourdomain.com/api/v1/health

# 3. Database is accessible
psql postgresql://user:pass@host/ecareafrica -c "SELECT 1;"

# 4. Can create student
curl -X POST https://api.yourdomain.com/api/v1/students \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{...}'

# 5. Can fetch devices
curl https://api.yourdomain.com/api/v1/devices \
  -H "Authorization: Bearer TOKEN"
```

---

**System Status:** 🟢 READY FOR PRODUCTION  
**Last Deployment:** [Your date]  
**Next Maintenance:** [Schedule here]

---

For detailed information, see: `PRODUCTION-READINESS-VALIDATION.md`
