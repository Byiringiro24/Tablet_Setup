$base = "http://localhost:5000/api/v1"
$tokens = @{}

$usersToTest = @(
  @("School Admin","admin@1.ecare.test","Password@123"),
  @("DOD","dod@1.ecare.test","Password@123"),
  @("DOS","dos@1.ecare.test","Password@123"),
  @("Patron","patron@1.ecare.test","Password@123"),
  @("Matron","matron@1.ecare.test","Password@123"),
  @("Boarding","boarding@1.ecare.test","Password@123"),
  @("GateKeeper","gatekeeper@1.ecare.test","Password@123"),
  @("Teacher","teacher1@1.ecare.test","Password@123"),
  @("Finance","finance@1.ecare.test","Password@123"),
  @("Staff","staff1@1.ecare.test","Password@123")
)

Write-Output ""
Write-Output "=== LOGIN TESTS ==="
foreach ($u in $usersToTest) {
  $lbl = $u[0]; $em = $u[1]; $pw = $u[2]
  $body = '{"email":"' + $em + '","password":"' + $pw + '"}'
  $tok = $null; $role = ""
  try {
    $r = Invoke-RestMethod -Uri "$base/auth/login" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 8
    $tok = $r.data.access_token
    $role = $r.data.user.role
  } catch {
    $code = [int]$_.Exception.Response.StatusCode
    Write-Output ("  FAIL " + $lbl + " HTTP " + $code)
    continue
  }
  $tokens[$lbl] = $tok
  Write-Output ("  OK   " + $lbl + " (" + $role + ")")
}

$ts = Get-Date -Format "HHmmss"
Write-Output ""
Write-Output "=== CREATE USER TESTS ==="

function TryCreate($caller, $tok, $role, $expect) {
  $em = "t" + $ts + (Get-Random -Max 9999) + "@x.com"
  $ph = "+2507" + (Get-Random -Minimum 10000000 -Maximum 99999999)
  $body = '{"name":"Test ' + $role + '","email":"' + $em + '","phone":"' + $ph + '","role":"' + $role + '","password":"Test@12345"}'
  try {
    $r = Invoke-RestMethod -Uri "$base/users" -Method POST -Body $body -ContentType "application/json" -Headers @{Authorization="Bearer $tok"} -TimeoutSec 8
    $uid = $r.data.id
    if ($expect -eq "ok") {
      Write-Output ("  OK   [" + $caller + "] create " + $role + " => allowed id=" + $uid)
    } else {
      Write-Output ("  WARN [" + $caller + "] create " + $role + " => SHOULD BE BLOCKED but got id=" + $uid)
    }
  } catch {
    $code = [int]$_.Exception.Response.StatusCode
    if ($expect -eq "block") {
      Write-Output ("  OK   [" + $caller + "] create " + $role + " => correctly blocked " + $code)
    } else {
      try { $msg = ($_.ErrorDetails.Message | ConvertFrom-Json).message } catch { $msg = "err" }
      Write-Output ("  FAIL [" + $caller + "] create " + $role + " => " + $code + " " + $msg)
    }
  }
}

if ($tokens["School Admin"]) {
  TryCreate "SchoolAdmin" $tokens["School Admin"] "teacher" "ok"
  TryCreate "SchoolAdmin" $tokens["School Admin"] "patron" "ok"
  TryCreate "SchoolAdmin" $tokens["School Admin"] "director_of_discipline" "ok"
} else { Write-Output "  SKIP SchoolAdmin no token" }

if ($tokens["DOD"]) {
  TryCreate "DOD" $tokens["DOD"] "patron" "ok"
  TryCreate "DOD" $tokens["DOD"] "teacher" "ok"
  TryCreate "DOD" $tokens["DOD"] "school_admin" "block"
} else { Write-Output "  SKIP DOD no token" }

if ($tokens["DOS"]) {
  TryCreate "DOS" $tokens["DOS"] "teacher" "ok"
  TryCreate "DOS" $tokens["DOS"] "patron" "block"
  TryCreate "DOS" $tokens["DOS"] "school_admin" "block"
} else { Write-Output "  SKIP DOS no token" }

Write-Output ""
Write-Output "=== DONE ==="
