using System.Collections.Generic;
using UnityEngine;

public class ExperimentReport
{
    private float experimentStartTime;
    private readonly List<string> entries = new List<string>();

    public void RecordExperimentStart()
    {
        experimentStartTime = Time.time;
        entries.Add($"[{0f:F3}s] Experiment Started");
    }

    public void RecordExperimentEnd()
    {
        entries.Add($"[{GetTimestamp():F3}s] Experiment Ended");
    }

    public void RecordBlockStart(int blockIndex)
    {
        entries.Add($"[{GetTimestamp():F3}s] Block {blockIndex + 1} Started");
    }

    public void RecordBlockEnd(int blockIndex)
    {
        entries.Add($"[{GetTimestamp():F3}s] Block {blockIndex + 1} Ended");
    }

    public void RecordStimulusStart(int blockIndex, int stimulusIndex, int trialIndex, float frequency)
    {
        entries.Add($"[{GetTimestamp():F3}s] Block {blockIndex + 1} | Stimulus {stimulusIndex + 1} | Trial {trialIndex + 1} | Freq {frequency}Hz - Started");
    }

    public void RecordStimulusEnd(int blockIndex, int stimulusIndex, int trialIndex, float frequency)
    {
        entries.Add($"[{GetTimestamp():F3}s] Block {blockIndex + 1} | Stimulus {stimulusIndex + 1} | Trial {trialIndex + 1} | Freq {frequency}Hz - Ended");
    }

    private float GetTimestamp()
    {
        return Time.time - experimentStartTime;
    }

    public string GenerateReport()
    {
        return string.Join("\n", entries);
    }

    public void SaveToFile()
    {
        string fileName = $"ExperimentReport_{System.DateTime.Now:yyyy-MM-dd_HH-mm-ss}.txt";
        string path = System.IO.Path.Combine(Application.persistentDataPath, fileName);
        System.IO.File.WriteAllText(path, GenerateReport());
        Debug.Log($"Report saved to: {path}");
    }

    public void Clear()
    {
        entries.Clear();
    }
}