Auth Server Demo
================
heimdall 인증 서버와 istio 인가 동작 방식 이해하기.

OAuth2 개념
----------
> OAuth는 인터넷 사용자들이 비밀번호를 제공하지 않고 다른 웹사이트 상의 자신들의 정보에 대해 웹사이트나 애플리케이션의 접근 권한을 부여할 수 있는 공통적인 수단으로서 사용되는, **접근 위임을 위한 개방형 표준**이다.

Authentication(인증) : 사원증/방문증 발급  
Authorization(허가, 인가) : 사원증/방문증을 제시하고 회사 리소스에 접근. 사원증이냐 방문증이냐 종류에 따라 접근 가능 scope이 다르다.

### roles
[oauth roles](https://datatracker.ietf.org/doc/html/rfc6749#section-1.1)  

`authorization server` : heimdall  
-> resource owner authentication(인증) 후 access-token 발급을 담당하는 서버  
`resource server` : dealibird  
-> access-token을 지참한 request에 대해 protected 리소스 응답 혹은 거절을 하는 서버  
`client` : dealibird  
`resource owner` : end-user

### grant_type
access token 발급 flow. Oauth2에는 여러가지 grant type이 있다. 예를 들면 이런 것들이 있음.
- Authorization code
- Implicit
- Resource Owner Password Credentials ✅
- Client Credentials ✅ 

(heimdall에서 사용하는 grant type 체크 표시)
![grant type](public/grant-types.png)
출처: https://www.codecademy.com/learn/user-authentication-authorization-express/modules/oauth-2/cheatsheet
![authorization code](public/authorization_code.png)
![implicit grant](public/implicit.png)
![password flow](public/resource_owner_password_credentials.png)
![client credentials](public/client_credentials.png)
![resource owner password credentials](public/resource_owner_password_credentials.png)

쿠버네티스 환경의 OAuth
-------------------
![archiecture2](public/architecture2.jpeg)
![architecture](public/architecture1.jpeg)

### envoy jwt authentication 동작 방식
[Envoy JWT auth](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/jwt_authn_filter.html?highlight=location)  
- default로 설정되어 있는 토큰 추출 location은 request header의 `Authorization: Bearer <token>` 이다.
- jwt signature verify에 jwks 사용.   
  hash 알고리즘이라면 secret key, rsa 방식이라면 public key를 jwks에서 retrieve해서 토큰 무결성 검증.

### istio authentication policy 설정
[Istio Authorization Concepts](https://istio.io/latest/docs/concepts/security/#authorization)  
Istio Authorization architecture
> **Each Envoy proxy runs an authorization engine that authorizes requests at runtime.** When a request comes to the proxy, the authorization engine evaluates the request context against the current authorization policies, and returns the authorization result, either ALLOW or DENY. Operators specify Istio authorization policies using .yaml files.

yaml 파일로 policy (rule) 명세. `RequestAuthentication`, `AuthorizationPolicy` 두가지가 필요하다.

[RequestAuthentication](https://istio.io/latest/docs/reference/config/security/request_authentication/)  
[AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/)  
예)
```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: httpbin
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: "issuer-foo"
    jwksUri: https://example.com/.well-known/jwks.json
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: foo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["issuer-foo/*"]
    to:
    - operation:
        hosts: ["example.com"]
  - from:
    - source:
        requestPrincipals: ["issuer-bar/*"]
    to:
    - operation:
        hosts: ["another-host.com"]

```
1) RequestAuthentication  
   `jwtRules` 
   - `issuer` : 토큰 발행자, 
   - `jwks` or `jwksUri` : 여기 있는 secret key나 public key로 토큰 signature 확인해서 무결성 검증
2) AuthorizationPolicy  
   `action` : CUSTOM, DENY, ALLOW  
   `rules` : requst 매칭 조건. 
   - `from` (어디서 온 request인지), 
   - `to` (어디가 destination인 request인지), 
   - `when` (key=value 인지. 예를들면 토큰 issuer 확인 등)

- istio는 이렇게 설정한 config를 타겟 endpoint들로 전송해서 각 envoy proxy에서 authentication 진행..?
- 이때 jwks의 k (jwt_secret_key) value는 `application.rb` 파일에 적은 secret_key랑 같은 값으로 하면 될 것 같다(base64 인코딩 된)..   
  이게 토큰 encode 할 때 사용한 값이니까, decode 할 때도 이걸로 하겠지?
  heimdall doorkeeper.rb 파일 secret_key config랑 kubectl describe로 jwks k 값 찾아서 base64 디코딩한 거 두 개 일치 하는 거 보면 맞는듯


### 클러스터에 배포된 auth policy 확인하기
```
kubectl get authorizationpolicy -n ssm-dev

kubectl describe authorizationpolicy/dealibird-matrix-ap -n ssm-dev

kubectl get requestauthentication -n ssm-dev

kubectl describe requestauthentication/dealibird-matrix-pa -n ssm-dev
```

Rails Authorization Server
--------------------------

api 모드로 시작하기
```
rails new auth-server-demo -d mysql --api
```

필요한 gem 설치
```
gem 'devise'
gem 'doorkeeper'
gem 'doorkeeper-jwt'

bundle install
```

devise 설정
```
rails g devise:install
rails g devise user
```

초기 설정 및 마이그레이션 파일 생성하기
```
rails generate doorkeeper:install
rails generate doorkeeper:migration
```

각 파일 수정  
`create_doorkeeper_tables.rb` 마이그레이션 파일, 필요 없는 테이블 주석 처리    
`doorkeeper.rb` : 모드, grant_type 설정, jwt 토큰 설정 등  
`router.rb` : 필요 없는 컨트롤러 skip

마이그레이션으로 테이블 생성하기
```
rails db:create
rails db:migrate
```

샘플 데이터 seed
```
rails db:seed
```

### 참고

[API endpoint description](https://github.com/doorkeeper-gem/doorkeeper/wiki/API-endpoint-descriptions-and-examples)  
[Client credentials flow](https://github.com/doorkeeper-gem/doorkeeper/wiki/Client-Credentials-flow)  
[Resource Owner PassWorld Credentials flow](https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Resource-Owner-Password-Credentials-flow)

#### create 
access 토큰 발급  
`POST /oauth/token`

**end-user를 위한 access-token 발행**    
params
```json
{
    "grant_type": "password",
    "email": "jjmmyyou111@deali.net",
    "password": "1234567",
    "client_id": "FGMYl6VvgIMO3zQJBRD5NotBavFpp3AEMOWRXDWe9Ic",
    "client_secret": "If5Jrfu7dsNm5Q426kDLZ8BTy6_UHQhoAUdcP3GtEIA"
}
```
output
```json
{
    "access_token": {access-token},
    "token_type": "Bearer",
    "expires_in": 431999,
    "refresh_token": "op79jDaDOLr3s-VDM7srcm7pvfAYrqSxkXL3EnW6A08",
    "created_at": 1650508325
}
```
`config/initializers/doorkeeper.rb ` 파일에 정의한 `resource_owner_from_credentials` 로직으로 유저를 검증한 뒤 access-token을 발급해줍니다.

**end-user 토큰 재발급**  
params
```json
{
    "grant_type": "refresh_token",
    "refresh_token": "op79jDaDOLr3s-VDM7srcm7pvfAYrqSxkXL3EnW6A08",
    "client_id": "FGMYl6VvgIMO3zQJBRD5NotBavFpp3AEMOWRXDWe9Ic",
    "client_secret": "If5Jrfu7dsNm5Q426kDLZ8BTy6_UHQhoAUdcP3GtEIA"
}
```
output
```json
{
    "access_token": {access-token},
    "token_type": "Bearer",
    "expires_in": 432000,
    "refresh_token": "lfb0EyCBSmrWs16h1NAEjtOaTPLtVMOrEdUXrovYx24",
    "created_at": 1650512756
}
```
지난 access-token 발급시 함께 줬던 refresh-token을 첨부하여 access-token을 재발급 받습니다.

**외부 서비스를 위한 access-token 발행**  
params
```json
{
    "grant_type": "client_credentials",
    "client_id": "FGMYl6VvgIMO3zQJBRD5NotBavFpp3AEMOWRXDWe9Ic",
    "client_secret": "If5Jrfu7dsNm5Q426kDLZ8BTy6_UHQhoAUdcP3GtEIA"
}
```
output
```json
{
    "access_token": {access-token},
    "token_type": "Bearer",
    "expires_in": 431999,
    "created_at": 1650511937
}
```
`Doorkeeper::Application` 레코드로 등록되어 있는 외부 서비스에 대해 access-token을 발급해줍니다.


#### revoke
access 토큰 무효화  
`POST /oauth/revoke`
params
```json
{
    "token": {access-token},
    "client_id": "FGMYl6VvgIMO3zQJBRD5NotBavFpp3AEMOWRXDWe9Ic",
    "client_secret": "If5Jrfu7dsNm5Q426kDLZ8BTy6_UHQhoAUdcP3GtEIA"
}
```
output
```json
{}
```
#### redirect_url `urn:ietf:wg:oauth:2.0:oob` 
redirect_uri가 따로 지정되지 않았을 때 기본값??
> This value indicates that Google's authorization server should return the authorization code in the browser's title bar. 

