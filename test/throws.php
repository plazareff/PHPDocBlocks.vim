<?php

class Test {


    public function test($test = "fu'nction\" name(){"){


        try {
            $somevar = "test";
        } catch(\HttpException $var) {return "m;return fjjf;essage";

        }
    }

    /**
     *
     * testNestedThrow
     *
     * @param $test
     * @throws \HttpException
     * @throws \Exception
     * @throws \LogicException
     * @return float
     */
    public function testNestedThrow($test)
    {
        try {
            $somevar = "test";
        }
        catch
            (
                \Exception
                $var
        )
        {
            throw
                new
                \HttpException 
                (
                    500
                )
                ;
        }
        try {
            $somevar = "test";
        }
       
        catch 
            
            (
            
              \Exception
           
              $var 
          
          )
        
        
        {
            return 4389403.44;
        }
        throw
            new
            \LogicException
            (
                "message"
            )
            ;
    }

}
