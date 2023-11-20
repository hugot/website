# [docs] Notities Over OpenLDAP

*Dit zijn mijn notities over OpenLDAP. Deze notities dienen een dubbele functie: ze zijn een referentie voor mezelf bij het leren over OpenLDAP, EN ik hoop anderen er ook wat aan hebben in hun eigen leerproces. Houd er rekening mee dat ik werk vanuit het perspectief van een Software Engineer, niet een certified LDAPer, of hoe zoiets ook mag heten in het vakgebied ;).*

Ondanks het feit dat LDAP vaak gebruikt wordt voor authenticatie doeleinden, is het eigenijk gewoon een database die geoptimaliseerd is voor lezen. Bij het lezen van artikelen over LDAP voelt het vaak alsof je in een ongeloofelijk complexe wereld terecht bent gekomen waarin je met domeinspecifieke termen voor enterprise sysadmins om de oren wordt geslagen. Als je geen interesse hebt in active directory functionaliteiten binnen een traditioneel netwerk van linux systemen, dan hoef je je over een heleboel van deze termen niet zoveel zorgen te maken.

## LDAP als database voor gebruikersaccounts

De rest van deze notities gaan over het gebruiken van LDAP als een database voor gebruikersaccounts, waar applicaties net als met een RDBMS verbinding mee kunnen maken voor de opslag en het ophalen van data. We behandelen onder andere het opzetten van OpenLDAP, het opzetten van replicatie tussen OpenLDAP instanties en het instellen van een applicatie, authelia, om van het cluster gebruik te maken.

## LDAP Termen

Hieronder volgen een paar LDAP-specifieke termen.

- **DN**: Distinguished Name
- **CN**: Common Name
- **DC**: Domain Component
- **DIT**: Directory Information Tree

Een **Domain Component** is een component van een domein, meestal is dit een DNS domein van een organisatie of applicatie. De componenten van een DNS domein worden begrensd door een punt (.). Dus het domein example.com heeft de componenten "example" en "com". Een **Common Name** verschilt van een **Domain Component** in de zin dat het een generale naam is die niet met domeinen te maken heeft. Een **Distinguished Name** is de unieke naam van een ldap record, bestaande uit de opstapeling van Common Names, Domain Components en andere attributen waarop een record geselecteerd kunnen worden. Stel we willen de gebruiker met de uid "jan" opzoeken in een LDAP database van de organisatie example.com, dan is de **Distinguished Name** dus `uid=jan,dc=example,dc=com`.

## Opzetten OpenLDAP

Installeer openldap met het commando `apt install slapd ldap-utils`. Configureer vervolgens de basis met het commando `dpkg-reconfigure slapd`.

Configuratie basis tonen: `ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -b cn=config dn` (alleen vanaf root gebruiker). Dit is een speciale ldap directory waarin de configuratie van de server zelf is vastgelegd en gewijzigd kan worden.

Directory Information Tree (DIT) tonen: `ldapsearch -x -LLL -H ldapi:/// -b dc=example,dc=com dn` (verander domein waar nodig). Dit is de hoofd directory van de ldap server.

## Schema's

Schema's bepalen, net als mysql table definities, de types van de objecten die in een directory kunnen worden opgeslagen. Bij OpenLDAP worden standaard een aantal schema's geleverd, maar deze zijn erg uitgebreid en complex, zeker voor gebruikersaccounts van een doorsnee website. Daarom gaan we ons eigen schema maken voor een gebruikerstype met alleen de attributen die we nodig hebben.

```
objectclass ( 1.3.6.1.4.1.54392.5.1632.1
    NAME 'com-example-Person'
    DESC 'A person affiliated with example.com.'
    STRUCTURAL
    MUST ( uid $ userPassword $ displayName $ mail )
    )
```

<aside>
**Private Enterprise Number / OID**
Het lange nummer aan het begin van de definitie van de objectclass is een OID. Hiervoor heb je een OID namespace nodig, die een "Private Enterprise Number" wordt genoemd en welke je aan kunt vragen via de IANA. PEN aanvragen worden door mensen beoordeeld en toegekend, dus het kan even duren voordat je aan de beurt bent. Het is een beetje een overgecompliceerd en bureaucratisch systeem waarvan de voordelen mij niet helemaal duidelijk zijn, maar het is nou eenmaal onderdeel van de RFC.

Als je geen zin hebt om te wachten op een toekenning van de IANA, dan is er deze website voor verkrijgen van OID zonder menselijke handeling: https://freeoid.pythonanywhere.com/ . Hier krijg je een sub-OID van een PEN die de IANA aan de maker van de website heeft toegekend.
</aside>

## Schema toevoegen

Om het nieuwe schema te gebruiken moeten we de configuratie van de LDAP server aanpassen. Bij oudere versies van OpenLDAP deed je dit door /etc/slapd.conf aan te passen, maar bij meer eigentijdse versies maak je hiervoor gebruik van de speciale configuratie directory binnen de LDAP server, cn=config genoemd.

Deze directory wijzig je net zoals je andere LDAP directories zou wijzigen, namelijk door middel van een ldif (LDAP Data Interchange Format) bestand. Dit is een bestand met omschrijvingen van records die aan een LDAP directory moeten worden toegevoegd. Een beetje zoals een .sql bestand met INSERT queries. Om een ldif bestand te maken van ons schema kunnen we de volgende commando's uitvoeren:

```bash
tmpdir="$(mktemp -d)"

tee > schemas.conf <<EOF
include /etc/ldap/schema/core.schema
include /etc/ldap/schema/cosine.schema
include /etc/ldap/schema/inetorgperson.schema
include /etc/ldap/schema/openldap.schema

include /pad/naar/ons/schema.schema (WIJZIGEN)
EOF

slaptest -f ./schemas.conf -F "$tmpdir"
```

<aside>
De include regels in het "schemas.conf" bestand dat hier gemaakt wordt laden datatypes in die met openldap meegeleverd worden. Als je andere/meer datatypes gebruikt dan in het voorbeeld, dan kan het zijn dat je andere bestanden moet includeren waar die types in gedefinieerd zijn.
</aside>

Dit commando maakt een representatie van een nieuwe cn=config directory in een mappenstructuur met ldif bestanden in een tijdelijke map. Bekijk de ldif bestanden van de geincludeerde schema's zo:

```bash
cd "$tmpdir/cn=config/cn=schema"
ls
```

Open het ldif bestand dat bij jouw schema hoort. Het heeft dezelfde naam als je aan het schema hebt gegeven, met een cn={x} prefix. Het zou ongeveer de volgende inhoud moeten hebben:

```
# AUTO-GENERATED FILE - DO NOT EDIT!! Use ldapmodify.
# CRC32 eceebaf6
dn: cn={1}example-com
objectClass: olcSchemaConfig
cn: {1}example-com
olcObjectClasses: {0}( 1.3.6.1.4.1.54392.5.1632.1 NAME com-example-Person' DESC 
 'A person affiliated with example.com.' STRUCTURAL MUST ( uid $ userPassword $ displayName $ mail ) )
structuralObjectClass: olcSchemaConfig
entryUUID: 112d022e-5cd9-103d-8da4-6b43adf243c1
creatorsName: cn=config
createTimestamp: 20230322084122Z
entryCSN: 20230322084122.015156Z#000000#000#000000
modifiersName: cn=config
modifyTimestamp: 20230322084122Z
```

Wijzig dit zodat het er als volgt uitziet:

```
dn: cn=example-com,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: example-com
olcObjectClasses: {0}( 1.3.6.1.4.1.54392.5.1632.1 NAME com-example-Person' DESC 
 'A person affiliated with example.com.' STRUCTURAL MUST ( uid $ userPassword $ displayName $ mail ) )
```

Dit schema kun je nu aan je configuratie toevoegen door middal van het `ldapadd` commando: `ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /pad/naar/schema.ldif`.

## Records (Gebruikers) Toevoegen

Voor het toevoegen van een gebruiker hebben we ook weer een ldif bestand nodig, dit keer voor het aanpassen van de feitelijke DIT van het root domein dat we hebben ingesteld bij de installatie van openldap.

```
dn: uid=hugo,dc=example,dc=com
objectClass: com-example-Person
displayName: Hugo
userPassword: {SSHA}REDACTED
mail: hugo@example.com
```

Het `userPassword` veld kun je genereren met het `slappasswd` commando:

```
slappasswd -h {SSHA} -s "$(read -rsp 'Password: ' password; echo "$password")"
```

ldif toepassen op database: `ldapadd -D cn=admin,dc=example,dc=com -W -x -H ldapi:/// -f ./adduser.ldif`

<aside>ldapadd is een alias voor `ldapmodify -a`</aside>

## Records Wijzigen

```
dn: uid=hugo,dc=example,dc=com
replace: mail
mail: hugo-newmail@maildomain.example.com
```

ldif met wijziging toepassen: `ldapmodify -D cn=admin,dc=example,dc=com -W -x -H ldapi:/// -f ./modifymail.ldif`

## Records Verwijderen

```
dn: uid=hugo,dc=example,dc=com
changetype: delete
```

## Records (Gebruikers) Groeperen

Het groeperen van gebruikers kan met het groupOfNames datatype.

```
dn: cn=superusers,dc=example,dc=com
objectClass: groupOfNames
cn: superusers
description: Administrators and people who found an exploit in our code.
member: uid=hugo,dc=example,dc=com
```

### Gebruiker Toevoegen

```
dn: cn=superusers,dc=example,dc=com
changetype: modify
add: member
member: uid=hugo,dc=example,dc=com
```

### Gebruiker Verwijderen

```
dn: cn=superusers,dc=example,dc=com
changetype: modify
delete: member
member: uid=hugo,dc=example,dc=com
```

## Replicatie

Voor replicatie zie
[deze](https://ubuntu.com/server/docs/service-ldap-replication) pagina van de ubuntu documentatie. Er is verder ook documentatie op de openldap website.

## SSL/TLS

Het instellen en gebruiken van TLS met openldap is dan misschien onnodig ingewikkeld, maar het is wel nodig voor de beveiligde verbinding van applicaties met de LDAP server.

In het kort: je hebt een root CA nodig, er is genoeg documentatie over hoe deze te produceren met openssl. Verder heb je een cert en een private key nodig. Om hier vervolgens gebruik van te maken moeten we een aantal waardes in onze `cn=config` directory aanpassen en een waarde aanpassen in het /etc/default/slapd configuratiebestand. Daarna **is het nodig om slapd opnieuw op te starten**.

### Aanpassingen cn=config

```
dn: cn=config
changetype: modify
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ssl/privkey.pem
-
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ldap/ssl/my-root.ca
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ssl/pubkey.crt
```

### Aanpassing /etc/default/slapd

Pas het bestand /etc/default/slapd de waarde van SLAPD_SERVICES aan zodat deze ldaps:/// includeert:

```
SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"
```

### Clients Gebruiken met TLS

Met StartTLS:

```
LDAPTLS_REQCERT=allow ldapsearch -ZZ -x -LLL -H ldap://ldap.example.com -D cn=admin,dc=example,dc=com -W -b dc=example,dc=com
```

Of direct met TLS (via ldaps://):

```
LDAPTLS_REQCERT=allow ldapsearch -x -LLL -H ldaps://ldap.example.com -D cn=admin,dc=example,dc=com -W -b dc=example,dc=com
```

## Authenticatie

De bind-DN `cn=admin,dc=example,dc=com` kan gebruikt worden voor alle mogelijke wijzigingen. Maar voor het gebruik van de ldap server met andere applicaties zoals authelia, is het toch wel fijn om apparte inlog gegevens aan te maken.

Een bind-DN is eigenlijk niets anders dan een object in de directory tree. Alles dat het attribuut `userPassword` heeft kan gebruikt worden als bind-DN. Je directory structuur kun je zo gek maken als je zelf wil.

Welke rechten een willekeurige bind-DN over de directory tree krijgt, kan ingesteld worden via access regels in de cn=config database. In de [openldap documentatie]() en in `man slapd.access` wordt het opstellen van deze regels uitgelegd. Het is sowieso wel aan te raden om andere access regels in te stellen dan de standaard, want zonder aanpassingen geeft openldap alles en iedereen zonder authenticatie lees-rechten.

### Voorbeeld: "o=access"

Omdat OpenLDAP veel vrijheid biedt in de structuur van onze directory, en in manieren om rechten van bind-DNs vast te leggen, is het makkelijk om dingen ingewikkelder te maken dan nodig. Een strategie die ik in zulke situaties graag hanteer is kijken hoe andere software projecten het probleem oplossen. Een stuk software waar ik relatief veel ervaring mee heb is MYSQL of, preciezer, mariaDB. MariaDB slaat database gebruikers en hun rechten op in een tabel van de speciale "mysql" database. Dit voorbeeld is daardoor geinspireerd: we gaan een speciale "o=access" directory maken waarin bind-DNs en hun rechten worden vastgelegd. De structuur van onze volledige DIT gaat er als volgt uitzien:

```
[ (root) dc=example,dc=com ]
  |
  |_ [ (organization) o=access,dc=example,dc=com ]
  |     |
  |     |_ [ (groupOfNames) cn=authentication,o=access,dc=example,dc=com ]
  |     |     |
  |     |     |_ +member: uid=authlia,o=access,dc=example,dc=com
  |     |     |_ +member: uid=registration,o=access,dc=example,dc=com
  |     |
  |     |_ [ (groupOfNames) cn=something-else,o=access,dc=example,dc=com ]
  |     |     |
  |     |     |_ +member: uid=registration,o=access,dc=example,dc=com
  |     |
  |     |_ [ (com-example-Person) uid=authelia,o=access,dc=example,dc=com ]
  |     |_ [ (com-example-Person) uid=registration,o=access,dc=example,dc=com ]
  |
  |
  |_ [ (organization) o=authentication,dc=example,dc=com ]
  |_ [ (organization) o=something-else,dc=example,dc=com ]
```

Zoals te zien, zal de o=access directory twee soorten objecten bevatten: `groupOfNames` en `com-example-Person`. Het `cn` component van iedere groupOfNames heeft de naam van een andere `organization` die naast `o=access` in de DIT bestaat. Door gebruikers van het type `com-example-Person` als lid van een dergelijke groep toe te voegen, zullen deze gebruikers gebruikt kunnen worden als bind-DNs voor de congruerende organizations. Kort gezegd: als de gebruiker `uid=authlia,o=access,dc=example,dc=com` aan de groep `cn=authentication,o=access,dc=example,dc=com` wordt toegevoegd, dan kan de DN van deze gebruiker vanaf dat moment gebruikt worden om toegang te krijgen tot `o=authentication,dc=example,dc=com`.

Hiermee wordt het volgende bereikt:

- Het is makkelijk om een bind-DN toegang te geven tot 1 of meerdere sub-organisaties in de DIT.
- Omdat alleen op het root-niveau van de DIT rechten worden beheerd, wordt onnodige complexiteit met rechten in meerdere lagen van sub-directories voorkomen.
- Net als een mariaDB database, is de ldap server met het gebruik van `organization` directories in de root van onze DIT in feite een multi-tennant database geworden. Een `organization` is in deze context als een `schema` in een mariaDB/MySQL database. En database gebruikers en hun rechten kunnen per `organization` worden bijgehouden.

#### olcAccess in cn=config

Om het bovenstaande mogelijk te maken is wel wat configuratie magie nodig. De regels die gevolgd moeten worden voor het toewijzen van rechten aan een bind-DN bij connectie staan vastgelegd in `olcDatabase{1}mdb,cn=config`.

```
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: to attrs=userPassword by anonymous auth
olcAccess: to dn.regex="o=([^,]+),dc=example,dc=com$" by group/groupOfNames/member.expand="cn=$1,o=access,dc=example,dc=com" manage
```

## Authelia Configuratie
