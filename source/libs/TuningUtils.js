/*
	A collection of functions for manipulating strings.
	Copyright (C) 2024 Alessandro Culatti

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

const VERSION = "1.0.0";

// Size in cents of a justly tuned perfect fifth.
const JUST_FIFTH = 1200.0 * Math.log2(3 / 2);
// Size in cents of a 12EDO perfect fifth.
const DEFAULT_FIFTH = 700.0;
// Size in cents of the smallest fifth in the diatonic range.  It's equal to the
// 7EDO fifth.
const SMALLEST_DIATONIC_FIFTH = 1200.0 / 7 * 4;
// Size in cents of the largest fifth in the diatonic range.  It's equal to the
// 5EDO fifth.
const LARGEST_DIATONIC_FIFTH = 1200.0 / 5 * 3;

// Size in cents of the syntonic comma.
const SYNTONIC_COMMA = 1200.0 * Math.log2(81 / 80);

// Note distance in the circle of fifths, from the note C.
const CIRCLE_OF_FIFTHS_DISTANCE = {
	"C": 0,
	"D": 2,
	"E": 4,
	"F": -1,
	"G": 1,
	"A": 3,
	"B": 5,
};

/**
 * Return the amount of cents necessary to tune the input note according to the
 * input fifth deviation from 12EDO.
 */
function circleOfFifthsTuningOffset(note, fifthDeviation, referenceNote = "A")
{
	// Get the tuning offset for the input note with respect to 12EDO, based on
	// its tonal pitch class.
	var noteLetter = "";
	switch (note.tpc1 % 7)
	{
		case 0:
			noteLetter = "C";
			break;
		
		case 2:
		case -5:
			noteLetter = "D";
			break;
		
		case 4:
		case -3:
			noteLetter = "E";
			break;
		
		case 6:
		case -1:
			noteLetter = "F";
			break;
		
		case 1:
		case -6:
			noteLetter = "G";
			break;
		
		case 3:
		case -4:
			noteLetter = "A";
			break;
		
		case 5:
		case -2:
			noteLetter = "B";
			break;
	}
	var tuningOffset = -TuningUtils.circleOfFifthsDistance(noteLetter, referenceNote) * fifthDeviation;
	
	// Add the tuning offset due to the accidental.  Each semitone adds 7 fifth
	// deviations to the note's tuning, because we have to move 7 steps in the
	// circle of fifths to get to the altered note.
	var tpcAccidental = Math.floor((note.tpc1 + 1) / 7) - 2;
	tuningOffset -= tpcAccidental * 7 * fifthDeviation;
	
	return tuningOffset;
}

/**
 * Distance between two notes according to the circle of fifths.
 */
function circleOfFifthsDistance(n1, n2)
{
	return CIRCLE_OF_FIFTHS_DISTANCE[n1] - CIRCLE_OF_FIFTHS_DISTANCE[n2];
}
