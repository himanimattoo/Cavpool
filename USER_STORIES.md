# User Stories & Requirements

## Must-Have Features

| Priority | User Story | Acceptance Criteria | Owner | Estimate |
|----------|------------|-------------------|-------|----------|
| Must-have | As a rider/driver, I want to sign up with my UVA email so that my account is verified | Can create account with @virginia.edu email; Email verification required; UVA NetBadge integration preferred | TBD | TBD |
| Must-have | As a rider, I want to request to join a ride | Can browse available rides; Can send join requests; Driver receives notification | TBD | TBD |
| Must-have | As a rider/driver, I want to input a destination and time | Can specify origin and destination; Can set preferred time/time range; Location search/autocomplete | TBD | TBD |
| Must-have | As a driver, I want to post a ride | Can create ride offers; Can specify seats, cost, preferences; Can set pickup/dropoff locations | TBD | TBD |
| Must-have | As a rider/driver, I want to end the ride | Both parties must confirm ride completion; Triggers payment processing; Enables rating system | TBD | TBD |
| Must-have | As a rider, I want to pay the driver via the app | Secure Stripe integration; Automatic payment on ride completion; Receipt generation | TBD | TBD |

## Should-Have Features

| Priority | User Story | Acceptance Criteria | Owner | Estimate |
|----------|------------|-------------------|-------|----------|
| Should-have | As a returning rider/driver, I want to reset my password | Password reset via email; Secure token generation; Account recovery flow | TBD | TBD |
| Should-have | As a rider, I want to choose rides based on cheapest route | Price comparison in search results; Sort by cost functionality; Cost breakdown display | TBD | TBD |
| Should-have | As a rider/driver, I want to message other users | In-app messaging system; Notification for new messages; Contact exchange option | TBD | TBD |

## Nice-to-Have Features

| Priority | User Story | Acceptance Criteria | Owner | Estimate |
|----------|------------|-------------------|-------|----------|
| Nice-to-have | As a rider, I want to request stops along the route | Can suggest intermediate stops; Driver can approve/reject; Cost adjustment for detours | TBD | TBD |

## Detailed User Journeys

### Rider Journey
1. **Registration**: Login with UVA credentials or @virginia.edu email
2. **Profile Setup**: Add name, photo, pronouns, bio, emergency contacts
3. **Search Rides**: Input destination and time preferences
4. **Filter Results**: By cargo space, cost, departure time
5. **Request Ride**: Send join request to driver
6. **Negotiate Details**: Discuss pickup location, timing via messaging
7. **Confirm Booking**: Lock in details and payment hold
8. **Check-In**: Confirm ride start with driver
9. **During Ride**: Access emergency features if needed
10. **Complete Ride**: Both parties confirm completion
11. **Payment**: Automatic payment processing via Stripe
12. **Rate Experience**: Rate driver and provide feedback

### Driver Journey
1. **Registration**: Login with UVA credentials
2. **Verification**: Upload driver's license and insurance
3. **Profile Setup**: Add vehicle info, preferences, emergency contacts
4. **Post Ride**: Create ride offer with details and pricing
5. **Manage Requests**: Review and approve/reject ride requests
6. **Coordinate**: Message riders about pickup details
7. **Confirm Booking**: Finalize all ride details
8. **Check-In**: Start ride with confirmed passengers
9. **Navigate**: Follow agreed route with any approved stops
10. **Complete Ride**: Confirm arrival and ride completion
11. **Receive Payment**: Automatic payment from Stripe
12. **Rate Passengers**: Provide feedback on rider behavior

## Safety Requirements
- Emergency contact integration for all users
- Panic button accessible during rides
- Location sharing with emergency contacts
- Route deviation monitoring
- Driver verification before first ride offer
- Mutual rating system to build trust

## Payment Requirements
- Stripe Connect integration for secure transactions
- Payment hold during ride booking
- Automatic release on ride completion
- Refund handling for cancellations
- Cost splitting for multiple passengers
- Transparent fee breakdown