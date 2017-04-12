<?php

class Test {


    public function test($test = "fu'nction\" name(){")
    {
        try {
            $somevar = "test";
        } catch(\HttpException $var) {
            return "m;return fjjf;essage";
        }
    }

    public function testStrings($test)
    {
        if($test === "Double quote string") {
                return "test\"test';)(}{";
        } elseif($test === "Single quote string") {
                return 'test\'test";)(}{';
        }
    }

    public function testIntegers($test)
    {
        if($test === "Unsigned int") {
            return 74348378437473473;
        } elseif($test === "Negative int") {
            return -38748343473748373473847384;
        } elseif($test === "Positive int") {
            return +6;
        }
    }

    public function testFloatingPointNumbers($test)
    {
        if($test === "Unsigned float") {
            return 74348378.437473473;
        } elseif($test === "Negative float") {
            return -387483434737.48373473847384;
        } elseif($test === "Positive float") {
            return +6.6;
        }
    }

    public function testBooleans($test)
    {
        if($test === "true bool") {
            return true;
        } elseif($test = "false bool") {
            return false;
        } elseif($test === "TrUe bool") {
            return TrUe;
        } elseif($test = "faLSe bool") {
            return faLSe;
        }
    }

    public function testArrays($test)
    {
        if($test === "array()") {
            return array("test",'test');
        } elseif($test = "array []") {
            return ["test", 'test'];
        }
    }

}
