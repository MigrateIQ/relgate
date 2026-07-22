using System;
using Newtonsoft.Json;

namespace Vulnerable;

public static class Program
{
    public static void Main()
    {
        var payload = JsonConvert.SerializeObject(new { message = "hello" });
        Console.WriteLine(payload);
    }
}
