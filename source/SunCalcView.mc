using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Position as Pos;
using Toybox.System;
using Toybox.Time.Gregorian;
using Astro as astro;

class SunCalc {

    hidden const PI   = Math.PI,
        RAD  = Math.PI / 180.0,
        PI2  = Math.PI * 2.0,
        DAYS = Time.Gregorian.SECONDS_PER_DAY,
        J1970 = 2440588,
        J2000 = 2451545,
        J0 = 0.0009;

    hidden const TIMES = [
        -18 * RAD,    // ASTRO_DAWN
        -12 * RAD,    // NAUTIC_DAWN
        -8 * RAD,     // BLUE_HOUR_ST
        -6 * RAD,     // DAWN
        -2 * RAD,      // BLUE_HOUR_END
        -0.833 * RAD, // SUNRISE
        -0.3 * RAD,   // SUNRISE_END
        0 * RAD,      // SUNRISE_GEO
        10 * RAD,      // GOLDEN_HOUR_AM
        null,         // NOON
        10 * RAD,
        0 * RAD,
        -0.3 * RAD,
        -0.833 * RAD,
        -2 * RAD,
        -6 * RAD,
        -8 * RAD,
        -12 * RAD,
        -18 * RAD
        ];

    var lastD, lastLng;
    var	n, ds, M, sinM, C, L, sin2L, dec, Jnoon, EoT, LST, altAz, sunriseAz, transitAlt, sunsetAz, 
        LSTh, LSTm, LSTs, sunriseSunsetHourAngle, cosSunriseAz, altRad, LC, MAzAlt;

    function initialize() {
        lastD = null;
        lastLng = null;
    }

    function fromJulian(j) {
        return new Time.Moment((j + 0.5 - J1970) * DAYS);
    }

    function round(a) {
        if (a > 0) {
            return (a + 0.5).toNumber().toFloat();
        } else {
            return (a - 0.5).toNumber().toFloat();
        }
    }

    // lat and lng in radians
    function calculate(moment, pos, what) {
        var lat = pos[0];
        var lng = pos[1];
        
        if (lat == 3.141592652126882d || lng == 3.141592652126882d) {
            lat = 0;
            lng = 0;
        }

        var d = moment.value().toDouble() / DAYS - 0.5 + J1970 - J2000;
        if (lastD != d || lastLng != lng) {
            n = round(d - J0 + lng / PI2);
//			ds = J0 - lng / PI2 + n;
            ds = J0 - lng / PI2 + n - 1.1574e-5 * 68;
            M = 6.240059967 + 0.0172019715 * ds;
            sinM = Math.sin(M);
            C = (1.9148 * sinM + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M)) * RAD;
            L = M + C + 1.796593063 + PI;
            sin2L = Math.sin(2 * L);
            dec = Math.asin( 0.397783703 * Math.sin(L) );
            Jnoon = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;
            lastD = d;
            lastLng = lng;

            var t = 2 * Math.PI * daysFrom1stJanNoon(moment) / 365;
            EoT = -0.0116 + 7.3453 * Math.sin(t + 6.229)
            + 9.9212 * Math.sin(2 * t + 0.3877)
            + 0.3363 * Math.sin(3 * t + 0.342)
            + 0.2316 * Math.sin(4 * t + 0.7531);

            var where = new Position.Location({
                :latitude  => lat,
                :longitude => lng,
                :format    => :radians,
            });

            var localMoment = Gregorian.localMoment(where, moment.value());
            var info = Gregorian.info(localMoment, Time.FORMAT_SHORT);

            var GMT = localMoment.getOffset().toFloat() / 3600;
            var LT = info.hour.toFloat() + info.min.toFloat() / 60 + info.sec.toFloat() / 3600; 

            LC = GMT - lng.toFloat() * 180 / Math.PI / 15;
            LST = LT - LC - EoT.toFloat() / 60;

            if (LST < 0) {
                LST += 24;
            }

            LSTh = LST.toNumber();
            LSTm = ((LST - LSTh) * 60).toNumber();
            LSTs = round((((LST - LSTh) * 60) - LSTm) * 60);

            var hourAngle = (LST * 15 - 180) * Math.PI / 180;

            altRad = Math.asin(Math.sin(lat) * Math.sin(dec) + Math.cos(lat) * Math.cos(dec) * Math.cos(hourAngle));
            
            var alt = altRad * 180 / Math.PI;

            // var azRad = Math.asin(-Math.sin(hourAngle) * Math.cos(dec) / Math.cos(altRad));

            var azRad = Math.acos((Math.sin(dec) * Math.cos(lat) - Math.sin(lat) * Math.cos(hourAngle) * Math.cos(dec)) / Math.cos(altRad));
            
            if (hourAngle > 0) {
                azRad = 2 * Math.PI - azRad;
            }

            if (azRad < 0) {
                azRad += 2 * Math.PI ;
            }

            var az = azRad * 180 / Math.PI;

            altAz = [alt, az];

            transitAlt = Math.asin(Math.sin(lat) * Math.sin(dec) + Math.cos(lat) * Math.cos(dec)) * 180 / Math.PI;
            //var sunriseSunsetHourAngle = Math.acos(-Math.tan(lat) * Math.tan(dec)); 

            var cosSunriseSunsetHourAngle = (Math.sin(-0.833 * RAD) - Math.sin(lat) * Math.sin(dec))
            / (Math.cos(lat) * Math.cos(dec));

            if (cosSunriseSunsetHourAngle < -1 || cosSunriseSunsetHourAngle > 1) {
                sunriseSunsetHourAngle = null;
            } else {
                sunriseSunsetHourAngle = Math.acos(cosSunriseSunsetHourAngle); 
            }

            if (sunriseSunsetHourAngle == null) {
                cosSunriseAz = null;
            } else {
                cosSunriseAz = Math.sin(dec) * Math.cos(lat) - Math.sin(lat) * Math.cos(sunriseSunsetHourAngle) * Math.cos(dec);
            }

            if (cosSunriseAz == null) {
                sunriseAz = null;
                sunsetAz = null;
            } else {
                sunriseAz = Math.acos(cosSunriseAz);
                sunriseAz *= 180 / Math.PI;
                sunsetAz = 360 - sunriseAz;
            }
            
            var today = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
            MAzAlt = astro.LunarAzEl(today.year, today.month, today.day, today.hour, today.min, today.sec, pos[0] * 180 / Math.PI, pos[1] * 180 / Math.PI, 0);
            System.println("az: " + MAzAlt[0] + ", alt: " + MAzAlt[1]);
        }

        if (what == NOON) {
            return fromJulian(Jnoon);
        }

        var x = (Math.sin(TIMES[what]) - Math.sin(lat) * Math.sin(dec)) / (Math.cos(lat) * Math.cos(dec));

        if (x > 1.0 || x < -1.0) {
            return null;
        }

        var ds = J0 + (Math.acos(x) - lng) / PI2 + n - 1.1574e-5 * 68;

        var Jset = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;
        if (what > NOON) {
            return fromJulian(Jset);
        }

        var Jrise = Jnoon - (Jset - Jnoon);

        return fromJulian(Jrise);
    }

        function lcToString(LC) {          
        var LCString = "";

        if (LC < 0) {
            LCString = "-";
            LC *= -1;
        }
        LC *= 60;

        var LCM = Math.floor(LC).toNumber();
        var LCS = Math.round(((LC - LCM) * 60).toNumber()).format("%02d");

        LCString += LCM;
        LCString += ":";
        LCString += LCS;

        return LCString;
        }

    function eotToString(EoT) {          
        var EoTString = "";

        if (EoT < 0) {
            EoTString = "-";
            EoT *= -1;
        }
            
        var EotMin = Math.floor(EoT).toNumber();
        var EotSec = Math.round(((EoT - EotMin) * 60).toNumber()).format("%02d");

        EoTString += EotMin;
        EoTString += ":";
        EoTString += EotSec;

        return EoTString;
    }

    function daysFrom1stJanNoon(moment) {
        var firstJanuaryAtNoon = firstJanuaryAtNoonOfCurrentYear(moment);
        var timeDistance = firstJanuaryAtNoon.subtract(moment);
        var dayOfTheYear = timeDistance.value().toDouble() / 86400;
        return dayOfTheYear;
    }

    function firstJanuaryAtNoonOfCurrentYear(moment) {
        var temp = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        var ye = temp.year.format("%04d").toNumber();

        var options = {
            :year   => ye,
            :month  => 1,
            :day    => 1,
            :hour   => 12,
            :minute => 0
        };

        return Gregorian.moment(options);
    }

    function momentToString(moment, is24Hour) {

        if (moment == null) {
            return "--:--";
        }

        var tinfo = Time.Gregorian.info(new Time.Moment(moment.value() + 30), Time.FORMAT_SHORT);
        var text;
        if (is24Hour) {
            text = tinfo.hour.format("%02d") + ":" + tinfo.min.format("%02d");
        } else {
            var hour = tinfo.hour % 12;
            if (hour == 0) {
                hour = 12;
            }
            text = hour.format("%02d") + ":" + tinfo.min.format("%02d");
            // wtf... get used to 24 hour format...
            if (tinfo.hour < 12 || tinfo.hour == 24) {
                text = text + " AM";
            } else {
                text = text + " PM";
            }
        }
        var today = Time.today();
        var days = ((moment.value() - today.value()) / Time.Gregorian.SECONDS_PER_DAY).toNumber();

        if (moment.value() > today.value() ) {
            if (days > 0) {
                text = text + " +" + days;
            }
        } else {
            days = days - 1;
            text = text + " " + days;
        }
        return text;
    }

    static function printMoment(moment) {
        var info = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.day.format("%02d") + "." + info.month.format("%02d") + "." + info.year.toString()
            + " " + info.hour.format("%02d") + ":" + info.min.format("%02d") + ":" + info.sec.format("%02d");
    }

    (:test) static function testCalc(logger) {

        var testMatrix = [
            [ 1496310905, 48.1009616, 11.759784, NOON, 1496315468 ],
            [ 1496310905, 70.6632359, 23.681726, NOON, 1496312606 ],
            [ 1496310905, 70.6632359, 23.681726, SUNSET, null ],
            [ 1496310905, 70.6632359, 23.681726, SUNRISE, null ],
            [ 1496310905, 70.6632359, 23.681726, ASTRO_DAWN, null ],
            [ 1496310905, 70.6632359, 23.681726, NAUTIC_DAWN, null ],
            [ 1496310905, 70.6632359, 23.681726, DAWN, null ],
            [ 1483225200, 70.6632359, 23.681726, SUNRISE, null ],
            [ 1483225200, 70.6632359, 23.681726, NOON, 1483266532 ],
            [ 1483225200, 70.6632359, 23.681726, ASTRO_DAWN, 1483247635 ],
            [ 1483225200, 70.6632359, 23.681726, NAUTIC_DAWN, 1483252565 ],
            [ 1483225200, 70.6632359, 23.681726, DAWN, 1483259336 ]
            ];

        var sc = new SunCalc();
        var moment;

        for (var i = 0; i < testMatrix.size(); i++) {
            moment = sc.calculate(new Time.Moment(testMatrix[i][0]),
                                  new Pos.Location(
                                      { :latitude => testMatrix[i][1], :longitude => testMatrix[i][2], :format => :degrees }
                                      ).toRadians(),
                                  testMatrix[i][3]);

            if (   (moment == null  && testMatrix[i][4] != moment)
                   || (moment != null && moment.value().toLong() != testMatrix[i][4])) {
                var val;

                if (moment == null) {
                    val = "null";
                } else {
                    val = moment.value().toLong();
                }

                logger.debug("Expected " + testMatrix[i][4] + " but got: " + val);
                logger.debug(printMoment(moment));
                return false;
            }
        }

        return true;
    }
}